import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import '../stores/session_store.dart';

class WebSocketService extends ChangeNotifier with WidgetsBindingObserver {
  WebSocketService(this._sessionStore) {
    _sessionStore.addListener(_onSessionChanged);
    WidgetsBinding.instance.addObserver(this);
    _onSessionChanged();
  }

  final SessionStore _sessionStore;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _connected = false;
  bool _connecting = false;
  bool _disposed = false;
  int _reconnectAttempt = 0;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _clueController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onNotification =>
      _notificationController.stream;
  Stream<Map<String, dynamic>> get onClue => _clueController.stream;
  bool get isConnected => _connected;

  void _onSessionChanged() {
    if (_sessionStore.isSignedIn) {
      _connect();
    } else {
      _disconnect();
    }
  }

  Future<void> _connect() async {
    if (_disposed ||
        !_sessionStore.isSignedIn ||
        _connected ||
        _connecting) {
      return;
    }

    _reconnectTimer?.cancel();
    _connecting = true;
    final token = await _sessionStore.accessToken();
    if (token == null || _disposed || !_sessionStore.isSignedIn) {
      _connecting = false;
      return;
    }

    try {
      final wsUri = Uri.parse(ApiConfig.wsUrl).replace(
        queryParameters: {'token': token},
      );
      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;
      if (_disposed || !_sessionStore.isSignedIn) {
        await _channel?.sink.close();
        _channel = null;
        return;
      }
      _connected = true;
      _connecting = false;
      _reconnectAttempt = 0;
      notifyListeners();

      _subscription = _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (_) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_connected && _channel != null) {
          try {
            _channel!.sink.add('ping');
          } catch (_) {}
        }
      });
    } catch (_) {
      _connecting = false;
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final text = raw.toString();
      if (text == 'pong') return;
      final json = jsonDecode(text) as Map<String, dynamic>;
      final event = json['event'] as String?;
      final data = json['data'] as Map<String, dynamic>? ?? {};

      switch (event) {
        case 'new_message':
          _messageController.add(data);
          break;
        case 'new_notification':
          _notificationController.add(data);
          break;
        case 'new_clue':
          _clueController.add(data);
          break;
      }
    } catch (e) {
      debugPrint('Erro ao processar mensagem do WebSocket: $e');
    }
  }

  void _handleDisconnect() {
    _connected = false;
    _connecting = false;
    _pingTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    notifyListeners();

    if (!_disposed && _sessionStore.isSignedIn) {
      _reconnectTimer?.cancel();
      final attempt = _reconnectAttempt > 4 ? 4 : _reconnectAttempt;
      final seconds = 2 * (1 << attempt);
      _reconnectAttempt = attempt + 1;
      _reconnectTimer = Timer(Duration(seconds: seconds), _connect);
    }
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _connected = false;
    _connecting = false;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connect();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _disconnect();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionStore.removeListener(_onSessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _disconnect();
    _messageController.close();
    _notificationController.close();
    _clueController.close();
    super.dispose();
  }
}
