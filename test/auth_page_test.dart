import 'package:catlogue/pages/auth_page.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<void> openLogin(WidgetTester tester, {double scale = 1}) async {
    final session = SessionStore();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: AuthPage(sessionStore: session, onContinueOffline: () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final platform in TargetPlatform.values) {
    testWidgets('Apple button visibility on $platform', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      await openLogin(tester);
      expect(
        find.text('Continuar com a Apple'),
        platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('Apple label fits width $width and text scale $scale', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await openLogin(tester, scale: scale);
        final label = find.text('Continuar com a Apple');
        await tester.ensureVisible(label);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final button = find.ancestor(
          of: label,
          matching: find.byType(ElevatedButton),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.textScaler.scale(14), closeTo(14 * scale, 0.01));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(
          tester.getRect(button).contains(tester.getRect(label).topLeft),
          isTrue,
        );
        expect(
          tester.getRect(button).contains(tester.getRect(label).bottomRight),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
