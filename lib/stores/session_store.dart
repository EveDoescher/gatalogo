import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/cat_database.dart';
import '../models/auth_session.dart';
import '../services/auth_api_service.dart';
import '../services/product_api_service.dart';
import '../services/websocket_service.dart';
import '../services/push_notification_service.dart';

class SessionStore extends ChangeNotifier {
  SessionStore({AuthApiService? api, FlutterSecureStorage? secureStorage})
    : _api = api ?? AuthApiService(),
      _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    webSocket = WebSocketService(this);
    pushNotifications = PushNotificationService(this);
  }

  static const _bundleKey = 'auth_session_v2';
  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';
  static const _profileKey = 'auth_local_profile';
  static const _avatarKey = 'auth_avatar_url';
  static const _autoSyncKey = 'auto_sync_enabled';
  bool _autoSyncEnabled = true;
  bool get autoSyncEnabled => _autoSyncEnabled;

  Future<void> setAutoSyncEnabled(bool value) async {
    await _secureStorage.write(key: _autoSyncKey, value: value.toString());
    _autoSyncEnabled = value;
    notifyListeners();
  }

  Future<String?>? _refreshing;
  int _sessionEpoch = 0;
  Future<void> _storageOperations = Future<void>.value();

  final AuthApiService _api;
  final FlutterSecureStorage _secureStorage;
  final CatDatabase _database = CatDatabase.instance;
  late final WebSocketService webSocket;
  late final PushNotificationService pushNotifications;
  AuthSession? _session;
  String? _avatarUrl;
  bool _isReady = false;
  bool _isBusy = false;

  AuthSession? get session => _session;
  String? get avatarUrl => _avatarUrl;
  bool get isSignedIn => _session != null;
  bool get isReady => _isReady;
  bool get isBusy => _isBusy;

  final _sessionExpiredController = StreamController<void>.broadcast();
  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  Future<void> initialize() async {
    try {
      _autoSyncEnabled =
          await _secureStorage.read(key: _autoSyncKey) != 'false';
      unawaited(pushNotifications.initialize());
      _avatarUrl = await _secureStorage.read(key: _avatarKey);
      Map<String, dynamic>? bundle;
      final stored = await _secureStorage.read(key: _bundleKey);
      if (stored != null) {
        try {
          bundle = Map<String, dynamic>.from(jsonDecode(stored) as Map);
        } catch (_) {
          /* Fall back to the legacy credentials if present. */
        }
      }
      final access =
          bundle?['access_token'] as String? ??
          await _secureStorage.read(key: _accessKey);
      final refresh =
          bundle?['refresh_token'] as String? ??
          await _secureStorage.read(key: _refreshKey);
      if (access != null && refresh != null) {
        final cached = bundle == null
            ? await _secureStorage.read(key: _profileKey)
            : jsonEncode(bundle);
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
          if (_session != null) {
            if (await accessToken() != null && _session != null) {
              await _persist(_session!);
            }
            return;
          }
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
      if (_session != null) {
        unawaited(syncAccountDetails());
      }
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
    unawaited(syncAccountDetails());
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
    unawaited(syncAccountDetails());
  }

  Future<void> loginWithApple({
    required String idToken,
    String? userIdentifier,
    String? email,
  }) async {
    final tokens = await _runResult(
      () async => _api.loginWithApple(
        idToken: idToken,
        deviceId: await deviceId(),
        userIdentifier: userIdentifier,
        email: email,
      ),
    );
    await _save(tokens);
    unawaited(syncAccountDetails());
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
    if (!refresh && !_expiresSoon(_session!.accessToken)) {
      return _session!.accessToken;
    }
    return _refreshing ??= _refreshAccessToken().whenComplete(
      () => _refreshing = null,
    );
  }

  bool _expiresSoon(String token) {
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      ) as Map;
      return (payload['exp'] as num) * 1000 <=
          DateTime.now().millisecondsSinceEpoch + 60000;
    } catch (_) {
      return false;
    }
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
      return identical(_session, refreshed) ? refreshed.accessToken : null;
    } on AuthApiException catch (error) {
      if (_session == previous &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        await clearLocalSession();
        _sessionExpiredController.add(null);
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

  Future<void> requestDeactivationCode() async {
    final token = _session?.accessToken;
    if (token == null) {
      throw const AuthApiException('Entre na sua conta para continuar.');
    }
    await _run(() => _api.requestDeactivationCode(token));
  }

  Future<void> confirmDeactivate({required String code}) async {
    final token = _session?.accessToken;
    if (token == null) {
      throw const AuthApiException('Entre na sua conta para continuar.');
    }
    await _run(() => _api.confirmDeactivate(token, code: code.trim()));
    await clearLocalSession();
  }

  Future<void> deactivate() async {
    final token = _session?.accessToken;
    if (token == null) return;
    await _api.deactivate(token);
    await clearLocalSession();
  }

  Future<void> updateAvatarUrl(String? url) async {
    _avatarUrl = url;
    if (url != null && url.isNotEmpty) {
      await _secureStorage.write(key: _avatarKey, value: url);
    } else {
      await _secureStorage.delete(key: _avatarKey);
    }
    notifyListeners();
  }

  Future<void> updateEmail(String newEmail) async {
    if (_session == null) return;
    _session = AuthSession(
      userId: _session!.userId,
      email: newEmail,
      accessToken: _session!.accessToken,
      refreshToken: _session!.refreshToken,
    );
    await _persist(_session!);
    notifyListeners();
  }

  Future<void> syncAccountDetails() async {
    if (_session == null) return;
    try {
      final productApi = ProductApiService(this);
      final accountData = await productApi.get('/app/account');
      final newAvatar = accountData['avatar_url'] as String?;
      if (newAvatar != _avatarUrl) {
        await updateAvatarUrl(newAvatar);
      }
    } catch (_) {
      // Ignora erro em offline
    }
  }

  Future<void> clearLocalSession() async {
    _sessionEpoch++;
    _session = null;
    _avatarUrl = null;
    await _withStorage(() async {
      for (final key in [
        _bundleKey,
        _accessKey,
        _refreshKey,
        _profileKey,
        _avatarKey,
      ]) {
        await _secureStorage.delete(key: key);
      }
    });
    notifyListeners();
  }

  Future<void> _save(AuthSession session) async {
    final epoch = _sessionEpoch;
    final accountChanged = _session?.userId != session.userId;
    await _persist(session);
    if (epoch != _sessionEpoch) return;
    _session = session;
    if (accountChanged) notifyListeners();
  }

  Future<void> _withStorage(Future<void> Function() operation) {
    final next = _storageOperations.then((_) => operation());
    _storageOperations = next.catchError((Object _) {});
    return next;
  }

  Future<void> _persist(AuthSession session) {
    final epoch = _sessionEpoch;
    return _withStorage(() async {
      if (epoch != _sessionEpoch) return;
      // Persist the rotated pair together; serialize with logout deletion.
      await _secureStorage.write(
        key: _bundleKey,
        value: jsonEncode({
          'user_id': session.userId,
          'email': session.email,
          'access_token': session.accessToken,
          'refresh_token': session.refreshToken,
        }),
      );
      await _secureStorage.delete(key: _accessKey);
      await _secureStorage.delete(key: _refreshKey);
      await _secureStorage.delete(key: _profileKey);
    });
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
    _sessionExpiredController.close();
    webSocket.dispose();
    unawaited(pushNotifications.dispose());
    super.dispose();
  }
}
