import 'dart:io';
import 'dart:ui' as ui;

import 'package:catlogue/widgets/illustrated_home_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  for (final width in [110.0, 140.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'ACC02 XP label stays within progress at width $width scale $scale',
        (tester) async {
          GoogleFonts.config.allowRuntimeFetching = false;
          const key = ValueKey('progress-evidence');
          const label = '3654 / 5000 XP';
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Center(
                    child: RepaintBoundary(
                      key: key,
                      child: SizedBox(
                        width: 200,
                        height: 130,
                        child: Center(
                          child: SizedBox(
                            width: width,
                            child: const IllustratedProgress(
                              current: 3654,
                              target: 5000,
                              label: label,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() => GoogleFonts.pendingFonts());
          await tester.pump();
          final output = Platform.environment['QUALITY_PROGRESS_IMAGES'];
          if (output != null) {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(key),
              );
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  '$output/w${width.toInt()}-s${(scale * 100).round()}.png',
                );
                expect(file.existsSync(), false);
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          final inner = tester.getRect(find.byType(IllustratedProgress));
          final boxes = paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: label.length),
          );
          expect(boxes, isNotEmpty);
          for (final box in boxes) {
            final top = paragraph.localToGlobal(Offset(box.left, box.top));
            final bottom = paragraph.localToGlobal(
              Offset(box.right, box.bottom),
            );
            expect(top.dy, greaterThanOrEqualTo(inner.top - .1));
            expect(
              bottom.dy,
              lessThanOrEqualTo(inner.bottom + .1),
              reason: 'Every XP line must remain visible',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
