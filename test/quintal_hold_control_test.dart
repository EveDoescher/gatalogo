import 'package:catlogue/widgets/quintal_hold_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'hold survives a second pointer and releases on cancellation or key up',
    (tester) async {
      var held = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => QuintalHoldControl(
                held: held,
                onChanged: (value) => update(() => held = value),
              ),
            ),
          ),
        ),
      );
      final control = find.byType(QuintalHoldControl);
      final first = await tester.startGesture(
        tester.getCenter(control),
        pointer: 1,
      );
      await tester.pump();
      expect(held, isTrue);
      expect(find.text('Solte para descer'), findsOneWidget);
      final second = await tester.startGesture(
        tester.getCenter(control),
        pointer: 2,
      );
      await first.up();
      await tester.pump();
      expect(held, isTrue);
      await second.cancel();
      await tester.pump();
      expect(held, isFalse);
      final listener = find.descendant(
        of: control,
        matching: find.byType(Listener),
      );
      Focus.of(tester.element(listener)).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(held, isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(held, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
