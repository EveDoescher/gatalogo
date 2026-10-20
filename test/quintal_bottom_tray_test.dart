import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/widgets/quintal_bottom_tray.dart';

void main() {
  for (final height in [640.0, 360.0]) {
    testWidgets('menu follows navigation and actual tray at height $height', (
      tester,
    ) async {
      tester.view.physicalSize = Size(320, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var open = false;
      var extent = 0.0;
      var contentHeight = 180.0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, height),
              padding: const EdgeInsets.only(bottom: 92, top: 24),
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Material(
                  child: Stack(
                    children: [
                      if (open)
                        QuintalBottomTray(
                          onExtentChanged: (value) =>
                              update(() => extent = value),
                          child: SizedBox(
                            height: contentHeight,
                            child: Column(
                              children: [
                                const Text('Bandeja'),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {},
                                  child: const Text('Última opção'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      QuintalFloatingMenu(
                        trayExtent: open ? extent : 0,
                        button: const SizedBox(
                          key: Key('plus'),
                          width: 52,
                          height: 52,
                        ),
                        actions: const [],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      final plus = find.byKey(const Key('plus'));
      expect(tester.getRect(plus).bottom, height - 92 - 8);
      update(() => open = true);
      await tester.pump();
      await tester.pump();
      final tray = find.byType(QuintalMeasuredHeight);
      expect(tester.getRect(tray).top - tester.getRect(plus).bottom, 8);
      // A changed panel must move the menu without knowing its fixed height.
      update(() => contentHeight = 700);
      await tester.pump();
      await tester.pump();
      expect(tester.getRect(tray).top - tester.getRect(plus).bottom, 8);
      expect(tester.getRect(plus).top, greaterThanOrEqualTo(24));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(find.text('Última opção').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      update(() => open = false);
      await tester.pump();
      expect(tester.getRect(plus).bottom, height - 92 - 8);
    });
  }
}
