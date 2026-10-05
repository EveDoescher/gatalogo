import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/widgets/post_composer.dart';

class _Account extends SessionStore {
  @override
  bool get isSignedIn => true;
  @override
  Future<String?> accessToken({bool refresh = false}) async => 'test';
}

void main() {
  testWidgets(
    'compact keyboard layout keeps labeled actions and editable location',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final session = _Account();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: PostComposer(session: session, initialNote: 'Meu passeio'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foto'), findsOneWidget);
      expect(find.text('Gato'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Praça do bairro');
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Praça do bairro'), findsOneWidget);
      expect(find.text('Meu passeio'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'text-only draft survives failed publication; unchanged retries reuse ID',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final session = _Account();
      final requests = <Map<String, dynamic>>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(home: PostComposer(session: session)),
          );
          await tester.enterText(
            find.byType(TextField).first,
            'Passeio com os gatinhos.',
          );
          await tester.pump();
          await tester.tap(find.text('Publicar'));
          await tester.pumpAndSettle();
          expect(find.text('Passeio com os gatinhos.'), findsOneWidget);
          expect(find.textContaining('Sua postagem está aqui'), findsOneWidget);
          await tester.tap(find.text('Publicar'));
          await tester.pumpAndSettle();
          expect(requests.length, 2);
          expect(requests[0]['request_id'], requests[1]['request_id']);
          expect(requests[0]['cat_name'], '');
          expect(requests[0].containsKey('photo_url'), false);
          await tester.enterText(
            find.byType(TextField).first,
            'Agora mudei o texto.',
          );
          await tester.pump();
          await tester.tap(find.text('Publicar'));
          await tester.pumpAndSettle();
          expect(requests[2]['request_id'], isNot(requests[0]['request_id']));
          await tester.tap(find.byTooltip('Fechar publicação'));
          await tester.pumpAndSettle();
          expect(find.text('Descartar publicação?'), findsOneWidget);
          await tester.tap(find.text('Continuar escrevendo'));
          await tester.pumpAndSettle();
          expect(find.text('Agora mudei o texto.'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          requests.add(Map<String, dynamic>.from(jsonDecode(request.body)));
          return http.Response('{"detail":"indisponível"}', 503);
        }),
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
