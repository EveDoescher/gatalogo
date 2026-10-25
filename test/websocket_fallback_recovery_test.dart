import 'package:catlogue/controllers/conversation_controller.dart';
import 'package:catlogue/services/social_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conversation_controller_test.dart' as fixture;

class _Socket extends fixture.Socket {
  _Socket(super.session);

  void disconnect() {
    connected = false;
    notifyListeners();
  }
}

class _History extends fixture.Api {
  _History(super.session);
  List<Map<String, dynamic>> rows = [];
  bool offline = false;

  @override
  Future<List<Map<String, dynamic>>> messages(String id) async {
    loads++;
    if (offline) throw const SocialApiException('controlled offline');
    return rows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final failedPoll in [false, true]) {
    testWidgets('RES06 fallback reconnect and events failedPoll=$failedPoll', (
      tester,
    ) async {
      final account = fixture.SwitchableAccount();
      final socket = _Socket(account)..connected = true;
      final api = _History(account);
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
        socket.incoming.add({
          'conversation_id': 'chat',
          'message': fixture.message('a-before'),
        });
        await tester.pump();
        expect(controller.messages.map((m) => m.id), ['a-before']);

        socket.disconnect();
        api.rows = [fixture.message('a-before'), fixture.message('b-during')];
        api.offline = failedPoll;
        await tester.pump(const Duration(seconds: 29));
        expect(api.loads, 1);
        await tester.pump(const Duration(seconds: 1));
        expect(api.loads, 2);
        if (failedPoll) {
          expect(controller.messages.map((m) => m.id), ['a-before']);
          api.offline = false;
          await tester.pump(const Duration(seconds: 30));
          expect(api.loads, 3);
        }
        expect(controller.messages.map((m) => m.id), ['a-before', 'b-during']);
        final beforeReconnect = api.loads;
        socket.reconnect();
        await tester.pump();
        expect(api.loads, beforeReconnect + 1);
        socket.incoming.add({
          'conversation_id': 'chat',
          'message': fixture.message('c-after'),
        });
        socket.incoming.add({
          'conversation_id': 'chat',
          'message': fixture.message('a-before'),
        });
        await tester.pump();
        expect(controller.messages.map((m) => m.id), [
          'a-before',
          'b-during',
          'c-after',
        ]);
        await tester.pump(const Duration(seconds: 60));
        expect(api.loads, beforeReconnect + 1);

        socket.disconnect();
        api.rows = [
          for (final id in ['a-before', 'b-during', 'c-after'])
            fixture.message(id),
        ];
        await tester.pump(const Duration(seconds: 30));
        expect(api.loads, beforeReconnect + 2);
        final beforeDispose = api.loads;
        controller.dispose();
        await tester.pump(const Duration(seconds: 90));
        expect(api.loads, beforeDispose);
      } finally {
        controller.dispose();
        socket.dispose();
        account.dispose();
      }
    });
  }
}
