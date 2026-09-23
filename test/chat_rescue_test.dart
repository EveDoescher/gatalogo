import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/models/chat_message.dart';
import 'package:catlogue/models/conversation_summary.dart';
import 'package:catlogue/pages/conversation_page.dart';
import 'package:catlogue/stores/session_store.dart';

void main() {
  group('ChatMessage model tests', () {
    test('serializes and deserializes text message', () {
      final msg = ChatMessage(
        id: 'msg-1',
        conversationId: 'conv-1',
        senderId: 'user-a',
        body: 'Vi um gato parecido na esquina!',
        type: 'text',
        createdAt: DateTime(2026, 9, 16, 10, 0),
      );

      expect(msg.isText, isTrue);
      expect(msg.isPhoto, isFalse);
      expect(msg.isLocation, isFalse);
      expect(msg.isCatCard, isFalse);
      expect(msg.previewText, 'Vi um gato parecido na esquina!');
      expect(msg.isMine('user-a'), isTrue);
      expect(msg.isMine('user-b'), isFalse);

      final map = msg.toMap();
      final fromMap = ChatMessage.fromMap(map);

      expect(fromMap.id, 'msg-1');
      expect(fromMap.body, 'Vi um gato parecido na esquina!');
      expect(fromMap.type, 'text');
    });

    test('photo message preview and properties', () {
      final photoMsg = ChatMessage(
        id: 'msg-photo',
        conversationId: 'conv-1',
        senderId: 'user-b',
        body: 'Olhe a foto dele',
        type: 'photo',
        mediaUrl: '/social/conversations/conv-1/photo/123.jpg',
        createdAt: DateTime(2026, 9, 16, 10, 5),
      );

      expect(photoMsg.isPhoto, isTrue);
      expect(photoMsg.previewText, 'Foto: Olhe a foto dele');
      expect(photoMsg.mediaUrl, '/social/conversations/conv-1/photo/123.jpg');
    });

    test('location message preview and properties', () {
      final locMsg = ChatMessage(
        id: 'msg-loc',
        conversationId: 'conv-1',
        senderId: 'user-b',
        body: 'Estava aqui',
        type: 'location',
        locationLat: -25.4284,
        locationLng: -49.2733,
        locationTitle: 'Praça Osório, Curitiba',
        createdAt: DateTime(2026, 9, 16, 10, 10),
      );

      expect(locMsg.isLocation, isTrue);
      expect(locMsg.previewText, 'Praça Osório, Curitiba (Estava aqui)');
      expect(locMsg.locationLat, -25.4284);
      expect(locMsg.locationLng, -49.2733);
    });

    test('cat card message preview and properties', () {
      final catCardMsg = ChatMessage(
        id: 'msg-cat',
        conversationId: 'conv-1',
        senderId: 'user-a',
        body: '',
        type: 'cat_card',
        catData: {
          'id': 'cat-123',
          'name': 'Mingau',
          'capture_number': 7,
          'coat': 'Rajado',
          'color': 'Laranja',
        },
        createdAt: DateTime(2026, 9, 16, 10, 15),
      );

      expect(catCardMsg.isCatCard, isTrue);
      expect(catCardMsg.previewText, 'Ficha de Mingau');
      expect(catCardMsg.catData?['name'], 'Mingau');
    });

    test('deleted and edited message states', () {
      final deletedMsg = ChatMessage(
        id: 'msg-del',
        conversationId: 'conv-1',
        senderId: 'user-a',
        body: 'Mensagem apagada',
        isDeleted: true,
        createdAt: DateTime(2026, 9, 16, 10, 20),
      );

      expect(deletedMsg.isDeleted, isTrue);
      expect(deletedMsg.previewText, 'Mensagem apagada');

      final editedMsg = deletedMsg.copyWith(
        isDeleted: false,
        body: 'Texto corrigido',
        isEdited: true,
      );
      expect(editedMsg.isEdited, isTrue);
      expect(editedMsg.isDeleted, isFalse);
      expect(editedMsg.body, 'Texto corrigido');
    });

    test('reactions serialization and toggling', () {
      final msgWithReactions = ChatMessage.fromMap({
        'id': 'msg-react',
        'conversation_id': 'conv-1',
        'sender_id': 'user-a',
        'body': 'Obrigado pela ajuda!',
        'reactions': {
          'heart': ['user-b', 'user-c'],
          'paw': ['user-b'],
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(msgWithReactions.reactions['heart'], contains('user-b'));
      expect(msgWithReactions.reactions['heart'], contains('user-c'));
      expect(msgWithReactions.reactions['paw']?.length, 1);
    });
  });

  group('ConversationSummary model tests', () {
    test('parses summary correctly with sighting context and unread count', () {
      final summary = ConversationSummary.fromMap({
        'id': 'conv-rescue-1',
        'other_user_id': 'user-obs',
        'other_username': 'observador_amigo',
        'other_avatar_url': '/avatars/obs.jpg',
        'is_online': true,
        'unread_count': 3,
        'sighting_context': true,
        'match_suggestion_id': 'sugg-99',
        'last_message': {
          'id': 'last-1',
          'conversation_id': 'conv-rescue-1',
          'sender_id': 'user-obs',
          'body': 'Acabei de avistar!',
          'type': 'text',
          'created_at': DateTime.now().toIso8601String(),
        },
      });

      expect(summary.id, 'conv-rescue-1');
      expect(summary.otherUsername, 'observador_amigo');
      expect(summary.isOnline, isTrue);
      expect(summary.unreadCount, 3);
      expect(summary.sightingContext, isTrue);
      expect(summary.matchSuggestionId, 'sugg-99');
      expect(summary.lastMessage?.body, 'Acabei de avistar!');
      expect(summary.formattedTime, isNotEmpty);
    });
  });

  group('ConversationPage widget tests', () {
    testWidgets('renders header, rescue banner, and action buttons', (tester) async {
      final session = SessionStore();
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationPage(
            sessionStore: session,
            conversationId: 'conv-test-123',
            initialUsername: 'resgatador_sp',
            initialIsOnline: true,
            initialSightingContext: true,
          ),
        ),
      );
      await tester.pump();

      // Verifica cabeçalho com nome do usuário e status Online
      expect(find.text('@resgatador_sp'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);

      // Verifica banner de avistamento / resgate
      expect(find.text('Pista de avistamento ativa'), findsOneWidget);
      expect(find.text('Foto'), findsOneWidget);
      expect(find.text('Localização'), findsOneWidget);
      expect(find.text('Ficha do Pet'), findsOneWidget);

      // Verifica campo de texto de envio
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Mensagem...'), findsOneWidget);
    });
  });
}
