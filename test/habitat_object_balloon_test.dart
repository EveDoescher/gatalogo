import 'package:catlogue/widgets/habitat_object_balloon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pan and zoom preserve attachment, including viewport edges', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const targetKey = ValueKey('actions');
    var taps = 0;
    Future<void> frame(Offset anchor, double height, {bool docked = false}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Stack(
              children: [
                Positioned.fill(
                  child: HabitatObjectBalloon(
                    anchor: anchor,
                    objectHeight: height,
                    docked: docked,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                      child: const SizedBox(
                        key: targetKey,
                        width: 180,
                        height: 100,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    for (final anchor in [
      const Offset(195, 420),
      const Offset(40, 420),
      const Offset(355, 420),
      const Offset(195, 160),
      const Offset(195, 810),
    ]) {
      for (final height in [30.0, 60.0, 120.0]) {
        await frame(anchor, height);
        final rect = tester.getRect(find.byKey(targetKey));
        expect(rect.center.dx, anchor.dx);
        expect(rect.bottom, anchor.dy - height - 10);
      }
    }
    // Invisible actions must not intercept the scene, even when their box
    // would still overlap the viewport after the object has left it.
    await frame(const Offset(-1, 420), 30);
    await tester.tapAt(const Offset(40, 340));
    expect(taps, 0);
    await frame(const Offset(195, 420), 30);
    await tester.tapAt(const Offset(195, 330));
    expect(taps, 1);
    // Choice trays deliberately remain docked; their layout ignores pan.
    await frame(const Offset(195, 420), 30, docked: true);
    final dock = tester.getRect(find.byKey(targetKey));
    await frame(const Offset(-100, 140), 120, docked: true);
    expect(tester.getRect(find.byKey(targetKey)), dock);
  });
}
