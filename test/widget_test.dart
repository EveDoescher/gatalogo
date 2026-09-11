import 'package:flutter_test/flutter_test.dart';

import 'package:catlogue/services/cat_preflight_service.dart';

void main() {
  test(
    'keeps the camera flow available when local validation is unavailable',
    () async {
      final result = await CatPreflightService().validate('missing-photo.jpg');

      expect(result.accepted, isTrue);
      expect(result.usedLocalModel, isFalse);
    },
  );

  test('exposes a clear rejection to the capture screen', () {
    const result = CapturePreflightResult.rejected('Aproxime-se do gato.');

    expect(result.accepted, isFalse);
    expect(result.message, 'Aproxime-se do gato.');
    expect(result.usedLocalModel, isTrue);
  });
}
