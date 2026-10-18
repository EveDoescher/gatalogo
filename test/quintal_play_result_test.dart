import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/game/quintal_play_result.dart';

void main() {
  test('shows only confirmed bond and explains temporary care bonus', () {
    final text = quintalPlayResultDescription({
      'care_effect': {
        'bond_gained': 2,
        'bond_total': 14,
        'play_bonus_after': 20,
      },
    });
    expect(text, contains('+2 de vínculo! Total: 14.'));
    expect(text, contains('24 horas'));
    expect(text, isNot(contains('+20')));
  });

  test('daily limit shows no repeated gain and no absent care bonus', () {
    final text = quintalPlayResultDescription({
      'care_effect': {
        'bond_gained': 0,
        'bond_total': 14,
        'play_bonus_after': 0,
      },
    });
    expect(text, contains('hoje já foi recebido'));
    expect(text, isNot(contains('+')));
    expect(text, isNot(contains('renovado')));
  });

  test('legacy or incomplete response does not invent earned points', () {
    for (final result in <Map<String, dynamic>>[
      {},
      {'care_effect': {'bond_gained': 2}},
    ]) {
      expect(quintalPlayResultDescription(result),
          'O cuidado foi registrado. Confira o vínculo na ficha do seu gato.');
    }
  });
}
