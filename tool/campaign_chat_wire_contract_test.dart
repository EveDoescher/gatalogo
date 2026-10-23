// Opt-in red contract audit; not part of a mutation baseline.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/controllers/conversation_controller.dart';

import '../test/conversation_controller_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'DATA08 real API envelope preserves message identity and content',
    (tester) async {
      final wire = jsonDecode(
        File(Platform.environment['QUALITY_CHAT_WIRE_FILE']!)
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(wire['data']);
      final message = Map<String, dynamic>.from(data['message']);
      final account = fixtures.SwitchableAccount();
      final socket = fixtures.Socket(account), api = fixtures.Api(account);
      final controller = ConversationController(
        account,
        data['conversation_id'],
        api: api,
        socket: socket,
      );
      try {
        controller.start();
        await tester.pump();
        socket.incoming.add(data);
        await tester.pump();
        expect(controller.messages, hasLength(1));
        final actual = controller.messages.single;
        File(Platform.environment['QUALITY_CHAT_CONSUMED_FILE']!)
            .writeAsStringSync(
              jsonEncode({
                'id': actual.id,
                'body': actual.body,
                'sender_id': actual.senderId,
                'conversation_id': actual.conversationId,
              }),
            );
        expect(actual.id, message['id']);
        expect(actual.body, message['body']);
        expect(actual.senderId, message['sender_id']);
      } finally {
        controller.dispose();
        socket.dispose();
        account.dispose();
      }
    },
  );
}
