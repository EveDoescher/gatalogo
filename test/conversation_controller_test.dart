import 'package:catlogue/models/auth_session.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/controllers/conversation_controller.dart';
import 'package:catlogue/services/social_api_service.dart';
import 'package:catlogue/services/websocket_service.dart';
import 'package:catlogue/stores/session_store.dart';

Map<String, dynamic> message(String id, {String type = 'text'}) => {
  'id': id,
  'conversation_id': 'chat',
  'sender_id': 'bob',
  'body': 'hello',
  'type': type,
  'created_at': '2026-10-21T10:00:00Z',
};

class SwitchableAccount extends SessionStore {
  AuthSession? identity;
  @override
  AuthSession? get session => identity;
  @override
  bool get isSignedIn => false;
  void changeAccount() {
    identity = const AuthSession(
      userId: 'new-user',
      email: 'new@example.com',
      accessToken: 'access',
      refreshToken: 'refresh',
    );
    notifyListeners();
  }
}

class Socket extends WebSocketService {
  Socket(super.session);
  final incoming = StreamController<Map<String, dynamic>>.broadcast();
  bool connected = false;
  @override
  Stream<Map<String, dynamic>> get onNewMessage => incoming.stream;
  @override
  bool get isConnected => connected;
  void reconnect() {
    connected = true;
    notifyListeners();
  }

  @override
  void dispose() {
    incoming.close();
    super.dispose();
  }
}

class Api extends SocialApiService {
  Api(super.session);
  Completer<Map<String, dynamic>>? pending;
  int loads = 0, sends = 0;
  String? lastType;
  bool reject = false;
  @override
  Future<Map<String, dynamic>> conversationDetails(String id) async => {
    'username': 'bob',
  };
  @override
  Future<List<Map<String, dynamic>>> messages(String id) async {
    loads++;
    return [];
  }

  @override
  Future<void> markRead(String id) async {}
  @override
  Future<String?> uploadChatPhoto(
    String id,
    List<int> bytes,
    String name,
  ) async => '/photo.jpg';
  @override
  Future<Map<String, dynamic>> sendMessage(
    String conversationId, {
    String body = '',
    String type = 'text',
    String? mediaUrl,
    double? locationLat,
    double? locationLng,
    String? locationTitle,
    Map<String, dynamic>? catData,
    String? replyToId,
  }) async {
    sends++;
    lastType = type;
    if (reject) throw const SocialApiException('offline');
    return pending == null ? message('sent', type: type) : pending!.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionStore session;
  late Socket socket;
  late Api api;
  late ConversationController controller;
  setUp(() {
    session = SwitchableAccount();
    socket = Socket(session);
    api = Api(session);
    controller = ConversationController(
      session,
      'chat',
      api: api,
      socket: socket,
    );
  });
  tearDown(() {
    controller.dispose();
    socket.dispose();
    session.dispose();
  });
  testWidgets(
    'reconnect reloads and dispose cancels subscriptions and fallback',
    (tester) async {
      controller.start();
      await tester.pump();
      expect(api.loads, 1);
      socket.reconnect();
      await tester.pump();
      expect(api.loads, 2);
      final old = controller;
      old.dispose();
      controller = ConversationController(
        session,
        'other',
        api: api,
        socket: socket,
      );
      socket.incoming.add(message('late'));
      await tester.pump(const Duration(seconds: 60));
      expect(old.messages, isEmpty);
      expect(api.loads, 2);
    },
  );
  testWidgets('echo before HTTP response reconciles one confirmed message', (
    tester,
  ) async {
    controller.start();
    await tester.pump();
    api.pending = Completer();
    final send = controller.sendMessage(body: 'hello');
    await tester.pump();
    expect(controller.optimisticIds.length, 1);
    socket.incoming.add(message('real'));
    await tester.pump();
    api.pending!.complete(message('real'));
    await send;
    await tester.pump();
    expect(controller.messages.map((m) => m.id), ['real']);
    expect(controller.optimisticIds, isEmpty);
    controller.dispose();
  });
  testWidgets('fallback retains optimistic send until HTTP confirms', (
    tester,
  ) async {
    controller.start();
    await tester.pump();
    api.pending = Completer();
    final send = controller.sendMessage(body: 'hello');
    await tester.pump();
    await controller.load(silent: true);
    expect(controller.messages.length, 1);
    api.pending!.complete(message('real'));
    await send;
    expect(controller.messages.single.id, 'real');
    controller.dispose();
  });
  testWidgets('failure removes optimistic message and restores draft', (
    tester,
  ) async {
    controller.dispose();
    final restored = <String>[];
    controller = ConversationController(
      session,
      'chat',
      api: api,
      socket: socket,
      onRestoreComposer: restored.add,
    );
    api.reject = true;
    await controller.sendMessage(body: ' draft ');
    expect(controller.messages, isEmpty);
    expect(controller.sending, isFalse);
    expect(restored, ['draft']);
  });
  testWidgets('uploaded photo dispatches its message', (tester) async {
    await controller.uploadPhoto([1, 2], 'cat.jpg');
    expect(api.sends, 1);
    expect(api.lastType, 'photo');
    expect(controller.messages.single.isPhoto, isTrue);
  });
  testWidgets(
    'account change discards a late send and blocks subsequent commands',
    (tester) async {
      controller.start();
      await tester.pump();
      api.pending = Completer();
      final send = controller.sendMessage(body: 'old account');
      await tester.pump();
      (session as SwitchableAccount).changeAccount();
      api.pending!.complete(message('old-confirmed'));
      await send;
      await tester.pump();
      expect(controller.messages, isEmpty);
      expect(controller.error, contains('conta mudou'));
      await controller.sendMessage(body: 'new account');
      expect(api.sends, 1);
      controller.dispose();
    },
  );
}
