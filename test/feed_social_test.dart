import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:catlogue/services/image_compression_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCompressionService', () {
    test('comprime e redimensiona imagem maior que maxDimension', () async {
      // Cria imagem em memória de 1600x1200 pixels
      final testImage = img.Image(width: 1600, height: 1200);
      img.fill(testImage, color: img.ColorRgb8(255, 100, 50));
      final rawBytes = Uint8List.fromList(img.encodeJpg(testImage));

      final compressedBytes = await ImageCompressionService.compressImage(
        rawBytes,
        maxDimension: 800,
        quality: 75,
      );

      expect(compressedBytes, isNotEmpty);
      final decoded = img.decodeImage(compressedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(800));
      expect(decoded.height, equals(600));
    });

    test('mantem imagem menor sem ultrapassar maxDimension', () async {
      final testImage = img.Image(width: 300, height: 200);
      img.fill(testImage, color: img.ColorRgb8(50, 150, 250));
      final rawBytes = Uint8List.fromList(img.encodeJpg(testImage));

      final compressedBytes = await ImageCompressionService.compressImage(
        rawBytes,
        maxDimension: 1280,
        quality: 80,
      );

      expect(compressedBytes, isNotEmpty);
      final decoded = img.decodeImage(compressedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(300));
      expect(decoded.height, equals(200));
    });

    test('retorna bytes originais de forma segura se formato for invalido', () async {
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final result = await ImageCompressionService.compressImage(invalidBytes);
      expect(result, equals(invalidBytes));
    });
  });
}
