// Local controller/inbox mechanisms; fake clocks/transports, no physical FCM.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/controllers/conversation_controller.dart';
import 'package:catlogue/stores/notification_store.dart';

import '../test/conversation_controller_test.dart' as fixtures;

class _Socket extends fixtures.Socket {
  _Socket(super.session);
  void disconnect() {
    connected = false;
    notifyListeners();
  }
}

class _HistoryApi extends fixtures.Api {
  _HistoryApi(super.session);
  Completer<List<Map<String, dynamic>>>? history;
  @override
  Future<List<Map<String, dynamic>>> messages(String id) {
    loads++;
    return history?.future ?? Future.value([]);
  }
}

class _ReadSocket extends fixtures.Socket {
  _ReadSocket(super.session);
  final receipts = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get onMessagesRead => receipts.stream;
  @override
  void dispose() {
    receipts.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'RES06 offline polling at 30s pauses online and resumes after disconnect',
    (tester) async {
      final account = fixtures.SwitchableAccount(),
          socket = _Socket(fixtures.SwitchableAccount());
      final api = fixtures.Api(account);
      final controller = ConversationController(
        account,
        'chat',
        api: api,
        socket: socket,
      );
      try {
        controller.start();
        await tester.pump();
        expect(api.loads, 1);
        await tester.pump(const Duration(seconds: 29));
        expect(api.loads, 1);
        await tester.pump(const Duration(seconds: 1));
        expect(api.loads, 2);
        socket.reconnect();
        await tester.pump();
        expect(api.loads, 3);
        await tester.pump(const Duration(seconds: 60));
        expect(api.loads, 3);
        socket.disconnect();
        await tester.pump(const Duration(seconds: 30));
        expect(api.loads, 4);
        socket.incoming.add(fixtures.message('after-reconnect'));
        await tester.pump();
        expect(controller.messages.map((m) => m.id), ['after-reconnect']);
      } finally {
        controller.dispose();
        socket.dispose();
        account.dispose();
      }
    },
  );
  for (final order in ['ws-first', 'http-first']) {
    testWidgets('DATA08 duplicate echo reconciles once order=$order', (
      tester,
    ) async {
      final account = fixtures.SwitchableAccount(),
          socket = fixtures.Socket(fixtures.SwitchableAccount());
      final api = fixtures.Api(account);
      final controller = ConversationController(
        account,
        'chat',
        api: api,
        socket: socket,
      );
      try {
        controller.start();
        await tester.pump();
        api.pending = Completer();
        final send = controller.sendMessage(body: 'hello');
        await tester.pump();
        expect(controller.optimisticIds, hasLength(1));
        if (order == 'ws-first') {
          socket.incoming.add({
            'conversation_id': 'chat',
            'message': fixtures.message('real'),
          });
          await tester.pump();
        }
        api.pending!.complete(fixtures.message('real'));
        await send;
        await tester.pump();
        socket.incoming.add({
          'conversation_id': 'chat',
          'message': fixtures.message('real'),
        });
        socket.incoming.add({
          'conversation_id': 'chat',
          'message': fixtures.message('real'),
        });
        await tester.pump();
        expect(controller.messages.map((m) => m.id), ['real']);
        expect(controller.optimisticIds, isEmpty);
      } finally {
        controller.dispose();
        socket.dispose();
        account.dispose();
      }
    });
  }
  for (final ids in [
    ['b', 'a'],
    ['a', 'b'],
  ]) {
    testWidgets('DATA08 equal timestamps are deterministic for $ids', (
      tester,
    ) async {
      final account = fixtures.SwitchableAccount();
      final socket = fixtures.Socket(account), api = _HistoryApi(account);
      api.history = Completer();
      final controller = ConversationController(
        account,
        'chat',
        api: api,
        socket: socket,
      );
      try {
        controller.start();
        await tester.pump();
        for (final id in ids) {
          socket.incoming.add({
            'conversation_id': 'chat',
            'message': fixtures.message(id),
          });
        }
        await tester.pump();
        expect(controller.messages.map((m) => m.id), ['a', 'b']);
        api.history!.complete([
          for (final id in ids.reversed) fixtures.message(id),
        ]);
        await tester.pump();
        expect(controller.messages.map((m) => m.id), ['a', 'b']);
      } finally {
        controller.dispose();
        socket.dispose();
        account.dispose();
      }
    });
  }
  testWidgets(
    'DATA08 read receipt survives delayed unread history and duplicate echo',
    (tester) async {
      final account = fixtures.SwitchableAccount()..changeAccount();
      final socket = _ReadSocket(account), api = _HistoryApi(account);
      final controller = ConversationController(
        account,
        'chat',
        api: api,
        socket: socket,
      );
      final mine = {...fixtures.message('mine'), 'sender_id': 'new-user'};
      const readAt = '2026-10-21T10:02:00Z';
      try {
        controller.start();
        await tester.pump();
        socket.incoming.add(mine);
        await tester.pump();
        api.history = Completer();
        final loading = controller.load(silent: true);
        await tester.pump();
        socket.receipts.add({'conversation_id': 'chat', 'read_at': readAt});
        await tester.pump();
        expect(controller.messages.single.isRead, isTrue);
        api.history!.complete([mine]);
        await loading;
        expect(controller.messages.single.isRead, isTrue);
        expect(controller.messages.single.readAt, DateTime.parse(readAt));
        socket.incoming.add(mine);
        socket.receipts.add({
          'conversation_id': 'chat',
          'read_at': '2026-10-21T10:01:00Z',
        });
        await tester.pump();
        expect(controller.messages.single.readAt, DateTime.parse(readAt));
      } finally {
        controller.dispose();
        socket.dispose();
        account.dispose();
      }
    },
  );
  testWidgets('DATA08 live event survives late empty history snapshot', (
    tester,
  ) async {
    final account = fixtures.SwitchableAccount(),
        socket = fixtures.Socket(fixtures.SwitchableAccount());
    final api = _HistoryApi(account)..history = Completer();
    final controller = ConversationController(
      account,
      'chat',
      api: api,
      socket: socket,
    );
    try {
      controller.start();
      await tester.pump();
      socket.incoming.add(fixtures.message('live'));
      await tester.pump();
      api.history!.complete([]);
      await tester.pump();
      expect(controller.messages.map((m) => m.id), ['live']);
    } finally {
      controller.dispose();
      socket.dispose();
      account.dispose();
    }
  });
  test(
    'DLV05 read acknowledgment from old owner cannot mark new owner inbox',
    () async {
      final saved = Completer<void>();
      var owner = 'A';
      final store = NotificationStore(
        loadItems: () async => [
          {'id': owner, 'created_at': '2026-10-22T12:00:00Z'},
        ],
        saveRead: (_) => saved.future,
      );
      try {
        await store.refresh();
        final previous = store.markRead('A');
        store.clear();
        owner = 'B';
        await store.refresh();
        saved.complete();
        await previous;
        expect(store.items.map((m) => m['id']), ['B']);
        expect(store.unreadCount, 1);
      } finally {
        store.dispose();
      }
    },
  );
  test(
    'DLV05 concurrent refresh triggers converge on one unread notification',
    () async {
      final page = Completer<List<Map<String, dynamic>>>();
      var calls = 0;
      final store = NotificationStore(
        loadItems: () {
          calls++;
          return page.future;
        },
        saveRead: (_) async {},
      );
      try {
        final first = store.refresh(), second = store.refresh();
        expect(calls, 1);
        page.complete([
          {'id': 'same', 'created_at': '2026-10-22T12:00:00Z'},
        ]);
        await Future.wait([first, second]);
        await store.refresh();
        expect(store.items.map((m) => m['id']), ['same']);
        expect(store.unreadCount, 1);
      } finally {
        store.dispose();
      }
    },
  );
}
