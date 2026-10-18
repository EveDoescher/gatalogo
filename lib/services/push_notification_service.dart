import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../stores/session_store.dart';
import 'social_api_service.dart';

class PushMessage {
  const PushMessage({required this.id, this.title, this.body});

  final String id;
  final String? title;
  final String? body;
}

/// Platform transport; inbox/navigation logic does not depend on a Firebase app.
abstract interface class PushMessagingSource {
  bool get supported;
  Future<void> initialize();
  Stream<RemoteMessage> get messages;
  Stream<RemoteMessage> get openedMessages;
  Stream<String> get tokenRefresh;
  Future<RemoteMessage?> initialMessage();
  Future<bool> requestPermission();
  Future<String?> token();
}

class _FirebaseMessagingSource implements PushMessagingSource {
  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  }

  @override
  Stream<RemoteMessage> get messages => FirebaseMessaging.onMessage;
  @override
  Stream<RemoteMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp;
  @override
  Stream<String> get tokenRefresh => FirebaseMessaging.instance.onTokenRefresh;
  @override
  Future<RemoteMessage?> initialMessage() =>
      FirebaseMessaging.instance.getInitialMessage();
  @override
  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() => FirebaseMessaging.instance.getToken();
}

class PushNotificationService {
  PushNotificationService(this._sessionStore, {PushMessagingSource? source})
    : _source = source ?? _FirebaseMessagingSource() {
    _sessionStore.addListener(_onSessionChanged);
  }

  final PushMessagingSource _source;

  final SessionStore _sessionStore;
  final _notificationController = StreamController<String>.broadcast();
  final _messageController = StreamController<PushMessage>.broadcast();
  final _openedController = StreamController<String>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription, _openedSubscription;
  final _receivedIds = <String>{}, _openedIds = <String>{};
  bool _disposed = false;
  bool _available = false;
  bool _initialized = false;
  String? _pendingOpenedNotificationId;

  Stream<String> get onNotification => _notificationController.stream;
  Stream<PushMessage> get onMessage => _messageController.stream;
  Stream<String> get onOpenedNotification => _openedController.stream;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    if (!_source.supported) return;
    try {
      await _source.initialize();
      if (_disposed) return;
      _available = true;
      _messageSubscription = _source.messages.listen(_receive);
      _openedSubscription = _source.openedMessages.listen(_opened);
      final initial = await _source.initialMessage();
      if (_disposed) return;
      if (initial != null) _opened(initial);
      _tokenSubscription = _source.tokenRefresh.listen(_register);
      await _sync();
    } catch (error) {
      debugPrint('Firebase Messaging indisponível nesta plataforma: $error');
    }
  }

  void _onSessionChanged() {
    if (_available && !_disposed) unawaited(_sync());
  }

  Future<void> _sync() async {
    if (!_available || _disposed || !_sessionStore.isSignedIn) return;
    try {
      if (!await _source.requestPermission() || _disposed) return;
      await _register(await _source.token());
    } catch (_) {
      // A caixa de entrada continua disponível caso a permissão seja negada.
    }
  }

  Future<void> _register(String? token) async {
    if (!_available ||
        _disposed ||
        !_sessionStore.isSignedIn ||
        token == null ||
        token.length < 20) {
      return;
    }
    try {
      await SocialApiService(_sessionStore).registerDeviceToken(token);
    } catch (_) {
      // Uma renovação de token ou nova sessão tenta registrar novamente.
    }
  }

  void _receive(RemoteMessage message) {
    if (_disposed) return;
    final id = message.data['notification_id'];
    if (id is String && id.isNotEmpty && _receivedIds.add(id)) {
      // Bound the process-local retry cache; the server owns durable receipts.
      if (_receivedIds.length > 256) _receivedIds.remove(_receivedIds.first);
      _notificationController.add(id);
      _messageController.add(
        PushMessage(
          id: id,
          title: message.notification?.title,
          body: message.notification?.body,
        ),
      );
    }
  }

  void _opened(RemoteMessage message) {
    if (_disposed) return;
    final id = message.data['notification_id'];
    if (id is! String || id.isEmpty || !_openedIds.add(id)) return;
    if (_openedIds.length > 256) _openedIds.remove(_openedIds.first);
    if (_openedController.hasListener) {
      _pendingOpenedNotificationId = null;
      _openedController.add(id);
    } else {
      // Only cold-start taps wait for the signed-in app to mount. A tap already
      // delivered to its listener must not reopen after that app is remounted.
      _pendingOpenedNotificationId = id;
    }
  }

  String? takePendingOpenedNotification() {
    final id = _pendingOpenedNotificationId;
    _pendingOpenedNotificationId = null;
    return id;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sessionStore.removeListener(_onSessionChanged);
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
    _pendingOpenedNotificationId = null;
    _receivedIds.clear();
    _openedIds.clear();
    await _notificationController.close();
    await _messageController.close();
    await _openedController.close();
  }
}
