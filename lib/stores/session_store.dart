import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/cat_database.dart';
import '../models/auth_session.dart';
import '../services/auth_api_service.dart';
import '../services/websocket_service.dart';
import '../services/push_notification_service.dart';

class SessionStore extends ChangeNotifier {
  SessionStore({AuthApiService? api, FlutterSecureStorage? secureStorage})
    : _api = api ?? AuthApiService(),
      _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    webSocket = WebSocketService(this);
    pushNotifications = PushNotificationService(this);
  }

  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';
  static const _profileKey = 'auth_local_profile';
  Future<String?>? _refreshing;

  final AuthApiService _api;
  final FlutterSecureStorage _secureStorage;
  final CatDatabase _database = CatDatabase.instance;
  late final WebSocketService webSocket;
  late final PushNotificationService pushNotifications;
  AuthSession? _session;
  bool _isReady = false;
  bool _isBusy = false;

  AuthSession? get session => _session;
  bool get isSignedIn => _session != null;
  bool get isReady => _isReady;
  bool get isBusy => _isBusy;

  Future<void> initialize() async {
    try {
      await pushNotifications.initialize();
      final access = await _secureStorage.read(key: _accessKey);
      final refresh = await _secureStorage.read(key: _refreshKey);
      if (access != null && refresh != null) {
        final cached = await _secureStorage.read(key: _profileKey);
        if (cached != null) {
          try {
            final data = jsonDecode(cached) as Map;
            _session = AuthSession(
              userId: data['user_id'] as String,
              email: data['email'] as String,
              accessToken: access,
              refreshToken: refresh,
            );
          } catch (_) {
            /* Ignore an incomplete local profile. */
          }
        }
        try {
          final account = await _api.me(access);
          _session = AuthSession(
            userId: account.userId,
            email: account.email,
            accessToken: access,
            refreshToken: refresh,
          );
        } on AuthApiException catch (error) {
          if (error.statusCode != 401 && error.statusCode != 403) return;
          try {
            final refreshed = await _api.refresh(
              refreshToken: refresh,
              deviceId: await deviceId(),
            );
            await _save(refreshed);
          } on AuthApiException catch (error) {
            if (error.statusCode == 401 || error.statusCode == 403) {
              await clearLocalSession();
            }
          }
        }
      }
    } finally {
      _isReady = true;
      notifyListeners();
    }
  }

  Future<String> deviceId() => _database.getOrCreateDeviceId();

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _run(() => _api.register(email: email.trim(), password: password));
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final tokens = await _runResult(
      () async => _api.verifyEmail(
        email: email.trim(),
        code: code.trim(),
        deviceId: await deviceId(),
      ),
    );
    await _save(tokens);
  }

  Future<void> login({required String email, required String password}) async {
    final tokens = await _runResult(
      () async => _api.login(
        email: email.trim(),
        password: password,
        deviceId: await deviceId(),
      ),
    );
    await _save(tokens);
  }

  Future<void> loginWithGoogle() async {
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    final googleSignIn = serverClientId.isEmpty
        ? GoogleSignIn()
        : GoogleSignIn(serverClientId: serverClientId);
    final account = await googleSignIn.signIn();
    final authentication = await account?.authentication;
    final idToken = authentication?.idToken;
    if (idToken == null) {
      throw const AuthApiException(
        'Não foi possível confirmar a conta Google.',
      );
    }
    final tokens = await _runResult(
      () async =>
          _api.loginWithGoogle(idToken: idToken, deviceId: await deviceId()),
    );
    await _save(tokens);
  }

  Future<void> requestPasswordReset(String email) =>
      _run(() => _api.requestPasswordReset(email.trim()));
  Future<void> resendVerification(String email) =>
      _run(() => _api.resendVerification(email.trim()));
  Future<String> verifyResetCode(String email, String code) =>
      _runResult(() => _api.verifyResetCode(email.trim(), code));
  Future<void> completeReset(String token, String password) =>
      _run(() => _api.completeReset(token, password));
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String password,
  }) => _run(
    () => _api.confirmPasswordReset(
      email: email.trim(),
      code: code.trim(),
      password: password,
    ),
  );

  Future<String?> accessToken({bool refresh = false}) async {
    if (_session == null) return null;
    if (!refresh) return _session!.accessToken;
    return _refreshing ??= _refreshAccessToken().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<String?> _refreshAccessToken() async {
    final previous = _session;
    if (previous == null) return null;
    try {
      final refreshed = await _api.refresh(
        refreshToken: previous.refreshToken,
        deviceId: await deviceId(),
      );
      if (_session != previous) return null;
      await _save(refreshed);
      return refreshed.accessToken;
    } on AuthApiException catch (error) {
      if (_session == previous &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        await clearLocalSession();
      }
      return null;
    }
  }

  Future<void> logout() async {
    final token = _session?.accessToken;
    if (token != null) {
      try {
        await _api.logout(token);
      } catch (_) {}
    }
    await clearLocalSession();
  }

  Future<void> deactivate() async {
    final token = _session?.accessToken;
    if (token == null) return;
    await _api.deactivate(token);
    await clearLocalSession();
  }

  Future<void> clearLocalSession() async {
    _session = null;
    await _secureStorage.delete(key: _accessKey);
    await _secureStorage.delete(key: _refreshKey);
    await _secureStorage.delete(key: _profileKey);
    notifyListeners();
  }

  Future<void> _save(AuthSession session) async {
    _session = session;
    await _secureStorage.write(key: _accessKey, value: session.accessToken);
    await _secureStorage.write(key: _refreshKey, value: session.refreshToken);
    await _secureStorage.write(
      key: _profileKey,
      value: jsonEncode({'user_id': session.userId, 'email': session.email}),
    );
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    await _runResult<void>(action);
  }

  Future<T> _runResult<T>(Future<T> Function() action) async {
    _isBusy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    webSocket.dispose();
    unawaited(pushNotifications.dispose());
    super.dispose();
  }
}
