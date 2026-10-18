import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/game/habitat_cat_coat.dart';
import 'package:catlogue/game/habitat_cat_animations.dart';
import 'package:catlogue/services/habitat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'coats preserve every clip geometry and share only the original shadows',
    () async {
      final original = HabitatCatAnimations();
      final whiteBrown = HabitatCatAnimations.coat(
        'bicolor_white_brown',
        original,
      );
      final orange = HabitatCatAnimations.coat('solid_orange', original);
      try {
        for (final clip in HabitatCatClip.values) {
          await whiteBrown.preload(clip);
          await orange.preload(clip);
          for (var direction = 0; direction < 4; direction++) {
            final base = original.frame(clip, .37, direction)!;
            final coat = whiteBrown.frame(clip, .37, direction)!;
            final other = orange.frame(clip, .37, direction)!;
            expect(coat.source, base.source);
            expect(coat.origin, base.origin);
            expect(coat.visible, base.visible);
            expect(identical(coat.shadow, base.shadow), isTrue);
            expect(identical(coat.image, other.image), isFalse);
            expect(coat.image.width, base.image.width);
            expect(coat.image.height, base.image.height);
          }
        }
        whiteBrown.dispose();
        expect(whiteBrown.frame(HabitatCatClip.idle, 0, 0), isNull);
        expect(orange.frame(HabitatCatClip.idle, 0, 0), isNotNull);
        expect(original.frame(HabitatCatClip.idle, 0, 0), isNotNull);
      } finally {
        whiteBrown.dispose();
        orange.dispose();
        original.dispose();
      }
    },
  );
  test('detector attributes select the requested classic coats', () {
    String skin(
      String color,
      String pattern, [
      List<String> colors = const [],
    ]) => HabitatCatCoat.resolve(
      primaryColor: color,
      coatType: pattern,
      colors: colors,
    );
    expect(skin('Cinza', 'Rajado'), 'tabby_gray');
    expect(skin('Marrom', 'Rajado'), 'tabby_brown');
    expect(skin('Laranja', 'Bicolor', ['Branco']), 'bicolor_orange_white');
    expect(skin('Laranja', 'Sólido'), 'solid_orange');
    expect(
      skin('Branco', 'Bicolor', ['Branco', 'Marrom']),
      'bicolor_white_brown',
    );
    expect(skin('Preto', 'Tuxedo'), 'tuxedo_black');
    expect(skin('Branco', 'Tricolor', ['Preto', 'Laranja']), 'calico');
    expect(skin('Branco', 'Tricolor', ['Cinza', 'Creme']), 'calico_dilute');
    expect(skin('Creme', 'Colorpoint', ['Marrom']), 'point_brown');
    expect(skin('Preto', 'Escaminha', ['Laranja']), 'tortie');
    expect(HabitatCatCoat.resolve(), 'solid_gray');
    expect(HabitatCatCoat.resolve(coatType: 'Colorpoint'), 'point_brown');
    expect(
      HabitatCatCoat.resolve(
        primaryColor: 'Outro',
        colors: ['Outro', 'Laranja'],
      ),
      'solid_orange',
    );
  });

  test('every detector combination resolves to a shipped appearance', () {
    final catalog = (jsonDecode(
      File('assets/habitat/cat_coats/catalog.json').readAsStringSync(),
    ) as List).map((r) => r['id']).toSet();
    const colors = [
      'Preto',
      'Branco',
      'Cinza',
      'Laranja',
      'Marrom',
      'Creme',
      'Outro',
    ];
    for (final pattern in [
      'Sólido',
      'Bicolor',
      'Tricolor',
      'Rajado',
      'Tuxedo',
      'Escaminha',
      'Colorpoint',
      'Outro',
    ]) {
      for (final base in colors) {
        for (final accent in colors) {
          final id = HabitatCatCoat.resolve(
            primaryColor: base,
            coatType: pattern,
            colors: [accent],
          );
          expect(catalog, contains(id), reason: '$pattern $base $accent');
        }
      }
    }
  });

  test('coat evidence survives the offline snapshot and old snapshots remain compatible', () {
    final cat = HabitatCat.fromMap({
      'id': 'cat',
      'name': 'Canela',
      'primary_color': 'Branco',
      'coat_type': 'Bicolor',
      'coat_colors': ['Branco', 'Marrom'],
    });
    final restored = HabitatCat.fromMap(jsonDecode(jsonEncode(cat.toMap())));
    expect(restored.coatType, 'Bicolor');
    expect(restored.coatColors, ['Branco', 'Marrom']);
    expect(
      HabitatCatCoat.resolve(
        primaryColor: restored.primaryColor,
        coatType: restored.coatType,
        colors: restored.coatColors,
      ),
      'bicolor_white_brown',
    );
    final legacy = HabitatCat.fromMap({
      'id': 'old',
      'name': 'Lua',
      'primary_color': 'Branco',
    });
    expect(legacy.coatType, isNull);
    expect(legacy.coatColors, isEmpty);
    expect(
      HabitatCatCoat.resolve(primaryColor: legacy.primaryColor),
      'solid_white',
    );
  });
}
