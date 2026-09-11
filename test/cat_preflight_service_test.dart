import 'dart:io';

import 'package:catlogue/services/cat_preflight_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Future<String> writeImage(img.Image image) async {
    final directory = await Directory.systemTemp.createTemp(
      'cat_preflight_test_',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    final file = File('${directory.path}${Platform.pathSeparator}photo.png');
    await file.writeAsBytes(img.encodePng(image));
    return file.path;
  }

  test('rejects an image that is too dark before loading the model', () async {
    final path = await writeImage(img.Image(width: 32, height: 32));

    final result = await CatPreflightService().validate(path);

    expect(result.accepted, isFalse);
    expect(
      result.message,
      'A foto está escura ou sem contraste. Tente com mais luz.',
    );
  });

  test('rejects a smooth image as excessively blurred', () async {
    final image = img.Image(width: 160, height: 100);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final value = 80 + (x * 95 ~/ (image.width - 1));
        image.setPixelRgb(x, y, value, value, value);
      }
    }
    final path = await writeImage(image);

    final result = await CatPreflightService().validate(path);

    expect(result.accepted, isFalse);
    expect(
      result.message,
      'A foto está muito borrada. Segure o celular firme e tente novamente.',
    );
  });
}
