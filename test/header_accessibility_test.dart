import 'dart:io';
import 'dart:ui' show ImageByteFormat, SemanticsAction;

import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/notification_store.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/widgets/app_widgets.dart';
import 'package:catlogue/widgets/inbox_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _Store extends CatStore {
  _Store(super.session, this.inbox);
  final NotificationStore inbox;
  @override
  NotificationStore get notifications => inbox;
}

const captureKey = ValueKey('header-capture');

Future<void> capture(WidgetTester tester, String name) async {
  final output = Platform.environment['QUALITY_HEADER_IMAGES'];
  if (output == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      final file = File('$output/$name.png');
      expect(file.existsSync(), isFalse, reason: 'Never overwrite evidence');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Widget app(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: RepaintBoundary(
        key: captureKey,
        child: SizedBox(width: 120, height: 90, child: Center(child: child)),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final illustrated in [false, true]) {
    for (final count in [0, 1, 18, 120]) {
      testWidgets(
        'ACC05 inbox action role and unread count illustrated=$illustrated count=$count',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final account = SessionStore();
          final inbox = NotificationStore(
            loadItems: () async => [
              for (var i = 0; i < count; i++) {'id': '$i', 'read_at': null},
            ],
            saveRead: (_) async {},
          );
          final store = _Store(account, inbox);
          try {
            await inbox.refresh();
            await tester.pumpWidget(
              app(InboxButton(store: store, illustrated: illustrated)),
            );
            await tester.runAsync(GoogleFonts.pendingFonts);
            await tester.pumpAndSettle();
            await capture(tester, 'inbox-$illustrated-$count');
            final data = tester
                .getSemantics(find.byType(InboxButton))
                .getSemanticsData();
            expect(data.label, 'Notificações');
            expect(data.value, count == 1 ? '1 não lida' : '$count não lidas');
            expect(data.flagsCollection.isButton, isTrue);
            expect(data.hasAction(SemanticsAction.tap), isTrue);
            if (count > 0) {
              expect(find.text(count > 99 ? '99+' : '$count'), findsOneWidget);
            }
          } finally {
            await tester.pumpWidget(const SizedBox());
            store.dispose();
            inbox.dispose();
            account.dispose();
            semantics.dispose();
          }
        },
      );
    }
  }
  for (final framed in [false, true]) {
    testWidgets('ACC05 profile avatar has action label framed=$framed', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final account = SessionStore();
      try {
        await tester.pumpWidget(
          app(UserAvatarButton(sessionStore: account, framed: framed)),
        );
        await tester.pumpAndSettle();
        await capture(tester, 'avatar-$framed');
        final data = tester
            .getSemantics(find.byType(UserAvatarButton))
            .getSemanticsData();
        expect(data.label, 'Perfil');
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox());
        account.dispose();
        semantics.dispose();
      }
    });
  }
}
