import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/theme/app_theme.dart';
import 'package:catlogue/widgets/botanical_scene.dart';

void main() {
  testWidgets('a detail route leaves the main-tab visual scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BotanicalLevelScope(
          level: BotanicalLevel.primary,
          child: BotanicalScaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BotanicalScaffold(body: SizedBox()),
                  ),
                ),
                child: const Text('Abrir detalhe'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<BotanicalScene>(find.byType(BotanicalScene)).mood,
      BotanicalMood.garden,
    );
    await tester.tap(find.text('Abrir detalhe'));
    await tester.pumpAndSettle();
    final detail = tester.widget<BotanicalScene>(find.byType(BotanicalScene));
    expect(detail.mood, BotanicalMood.quiet);
    expect(detail.color, AppColors.background);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('internal task overrides the main-tab setting', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BotanicalLevelScope(
          level: BotanicalLevel.primary,
          child: BotanicalScaffold(
            level: BotanicalLevel.tertiary,
            body: SizedBox(),
          ),
        ),
      ),
    );
    final task = tester.widget<BotanicalScene>(find.byType(BotanicalScene));
    expect(task.color, AppColors.surface);
    expect(task.mood, BotanicalMood.quiet);
    await tester.pumpWidget(const SizedBox());
  });
}
