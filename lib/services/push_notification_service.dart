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

class PushNotificationService {
  PushNotificationService(this._sessionStore) {
    _sessionStore.addListener(_onSessionChanged);
  }

  final SessionStore _sessionStore;
  final _notificationController = StreamController<String>.broadcast();
  final _messageController = StreamController<PushMessage>.broadcast();
  final _openedController = StreamController<String>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  bool _available = false;
  bool _initialized = false;
  String? _pendingOpenedNotificationId;

  Stream<String> get onNotification => _notificationController.stream;
  Stream<PushMessage> get onMessage => _messageController.stream;
  Stream<String> get onOpenedNotification => _openedController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _available = true;
      FirebaseMessaging.onMessage.listen(_receive);
      FirebaseMessaging.onMessageOpenedApp.listen(_opened);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _opened(initial);
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        _register,
      );
      await _sync();
    } catch (error) {
      debugPrint('Firebase Messaging indisponível nesta plataforma: $error');
    }
  }

  void _onSessionChanged() {
    if (_available) unawaited(_sync());
  }

  Future<void> _sync() async {
    if (!_available || !_sessionStore.isSignedIn) return;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _register(await FirebaseMessaging.instance.getToken());
    } catch (_) {
      // A caixa de entrada continua disponível caso a permissão seja negada.
    }
  }

  Future<void> _register(String? token) async {
    if (!_available ||
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
    final id = message.data['notification_id'];
    if (id is String && id.isNotEmpty) {
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
    final id = message.data['notification_id'];
    if (id is! String || id.isEmpty) return;
    _pendingOpenedNotificationId = id;
    _openedController.add(id);
  }

  String? takePendingOpenedNotification() {
    final id = _pendingOpenedNotificationId;
    _pendingOpenedNotificationId = null;
    return id;
  }

  Future<void> dispose() async {
    _sessionStore.removeListener(_onSessionChanged);
    await _tokenSubscription?.cancel();
    await _notificationController.close();
    await _messageController.close();
    await _openedController.close();
  }
}
