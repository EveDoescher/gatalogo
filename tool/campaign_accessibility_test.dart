// Explicit desktop audit: flutter test --no-pub tool/campaign_accessibility_test.dart
// Uses real app widgets. Does not claim TalkBack/VoiceOver or device coverage.
import 'dart:convert';
import 'dart:io';

import 'package:catlogue/pages/auth_page.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/theme/app_theme.dart';
import 'package:catlogue/widgets/quintal_hold_control.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void record(String id, Map<String, Object?> value) {
  final folder = Platform.environment['QUALITY_ACC_OUTPUT'];
  if (folder == null) return;
  final file = File('$folder/$id.json');
  expect(file.existsSync(), isFalse, reason: 'Do not overwrite evidence');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(value));
}

Future<Map<String, Object?>> guidelines(WidgetTester tester) async {
  final results = <String, Object?>{};
  for (final entry in {
    'textContrast': textContrastGuideline,
    'androidTarget': androidTapTargetGuideline,
    'iosTarget': iOSTapTargetGuideline,
    'labels': labeledTapTargetGuideline,
  }.entries) {
    final evaluation = await entry.value.evaluate(tester);
    results[entry.key] = {
      'passed': evaluation.passed,
      'reason': evaluation.reason,
    };
  }
  return results;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final width in [320.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('ACC login width=$width scale=$scale', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final account = SessionStore();
          addTearDown(account.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: AuthPage(sessionStore: account, onContinueOffline: () {}),
            ),
          );
          await tester.runAsync(() async {
            await GoogleFonts.pendingFonts();
          });
          await tester.pumpAndSettle();
          final error = tester.takeException();
          final findings = await guidelines(tester);
          final overflows = <String>[];
          for (final element in find.byType(Text).evaluate()) {
            final render = element.renderObject;
            if (render is RenderParagraph && render.didExceedMaxLines) {
              overflows.add((element.widget as Text).data ?? '<rich text>');
            }
          }
          record('login-$width-$scale', {
            'scenarios': ['ACC-01', 'ACC-02', 'ACC-03', 'ACC-05', 'ACC-07'],
            'widget': 'AuthPage',
            'width': width,
            'height': 800,
            'scale': scale,
            'guidelines': findings,
            'layoutError': error?.toString(),
            'clippedLabels': overflows,
            'scope': 'Initial visible viewport only. Scrolled states and device readers pending.',
          });
          await tester.pumpWidget(const SizedBox());
          expect(error, isNull);
          expect(overflows, isEmpty);
          expect(
            findings.values.every((v) => (v as Map)['passed'] == true),
            isTrue,
            reason: jsonEncode(findings),
          );
        } finally {
          handle.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }

  for (final scale in [1.0, 2.0]) {
    for (final reduced in [false, true]) {
      testWidgets('ACC hold scale=$scale reduced=$reduced', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var held = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 800),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: reduced,
                ),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 280,
                      child: StatefulBuilder(
                        builder: (context, setState) => QuintalHoldControl(
                          held: held,
                          onChanged: (value) => setState(() => held = value),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() async {
            await GoogleFonts.pendingFonts();
          });
          await tester.pumpAndSettle();
          final node = tester.getSemantics(find.byType(QuintalHoldControl));
          final before = node.getSemanticsData();
          final meaningful =
              before.label.contains('Subir') &&
              before.value == 'Descendo' &&
              before.hasAction(SemanticsAction.tap);
          // Actual Semantics action, no pointer-specific fallback.
          // This SDK exposes the view SemanticsOwner through pipelineOwner.
          // Keep dispatch on the measured node owner (root owner may have no view).
          // ignore: deprecated_member_use
          tester.binding.pipelineOwner.semanticsOwner!.performAction(
            node.id,
            SemanticsAction.tap,
          );
          await tester.pumpAndSettle();
          final changed =
              held &&
              tester
                      .getSemantics(find.byType(QuintalHoldControl))
                      .getSemanticsData()
                      .value ==
                  'Subindo';
          final findings = await guidelines(tester);
          final duration = tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: find.byType(QuintalHoldControl),
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .duration;
          final motion = !reduced || duration == Duration.zero;
          final size = tester.getSize(find.byType(QuintalHoldControl));
          record('hold-$scale-$reduced', {
            'scenarios': [
              'ACC-01',
              'ACC-02',
              'ACC-03',
              'ACC-05',
              'ACC-06',
              'ACC-07',
            ],
            'widget': 'QuintalHoldControl',
            'scale': scale,
            'disableAnimations': reduced,
            'guidelines': findings,
            'semanticMeaningful': meaningful,
            'semanticActionChangesState': changed,
            'animationDurationMs': duration.inMilliseconds,
            'respectsReducedMotion': motion,
            'width': size.width,
            'height': size.height,
            'scope': 'Desktop Semantics and preference signal; no screen reader device execution.',
          });
          await tester.pumpWidget(const SizedBox());
          expect(meaningful && changed && motion, isTrue);
          expect(size.width >= 48 && size.height >= 48, isTrue);
          expect(
            findings.values.every((v) => (v as Map)['passed'] == true),
            isTrue,
            reason: jsonEncode(findings),
          );
        } finally {
          handle.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
