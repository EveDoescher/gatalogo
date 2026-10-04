import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/pages/friends_page.dart';
import 'package:catlogue/pages/public_profile_page.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/widgets/profile_qr_dialog.dart';

void main() {
  group('ProfileQrDialog widget tests', () {
    testWidgets('renders QR dialog with user handle and sharing options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileQrDialog(username: 'astrogato'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('QR Code de Amigo'), findsOneWidget);
      expect(
        find.text('Aponte a câmera para conectar e ver o perfil de @astrogato no Gatálogo:'),
        findsOneWidget,
      );
      expect(find.text('astrogato'), findsOneWidget);
      expect(find.text('Copiar Link'), findsOneWidget);
      expect(find.text('Compartilhar'), findsOneWidget);
    });
  });

  group('PublicProfilePage widget tests', () {
    testWidgets('renders loading state initially and handles unauthenticated state gracefully', (tester) async {
      final session = SessionStore();
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: PublicProfilePage(
            username: 'amigo_teste',
            sessionStore: session,
          ),
        ),
      );

      // Initially shows app bar with username and loading indicator
      expect(find.text('@amigo_teste'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      // Should handle offline / error state without crashing
      expect(find.text('@amigo_teste'), findsOneWidget);
    });
  });

  group('FriendsPage widget tests', () {
    testWidgets('renders 4 tabs: Amigos, Descobrir, Convites, Ranking', (tester) async {
      final session = SessionStore();
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: FriendsPage(sessionStore: session),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Amigos'), findsWidgets);
      expect(find.text('Descobrir'), findsOneWidget);
      expect(find.text('Convites'), findsOneWidget);
      expect(find.text('Ranking'), findsOneWidget);

      // Switch to Descobrir tab
      await tester.tap(find.text('Descobrir'));
      await tester.pumpAndSettle();

      // Check Descobrir quick actions
      expect(find.text('Meu QR Code'), findsOneWidget);
      expect(find.text('Convidar Amigo'), findsOneWidget);
      expect(find.text('Buscar exploradores por @nome...'), findsOneWidget);

      // Switch to Ranking tab
      await tester.tap(find.text('Ranking'));
      await tester.pumpAndSettle();

      expect(find.text('Sem ranking semanal ainda'), findsOneWidget);

      // Switch to Convites tab
      await tester.tap(find.text('Convites'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum convite pendente'), findsOneWidget);
    });
  });
}
