import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageCompressionService {
  const ImageCompressionService._();

  /// Comprime e redimensiona a imagem de forma assíncrona fora da UI thread via isolate.
  static Future<Uint8List> compressImage(
    Uint8List rawBytes, {
    int maxDimension = 1280,
    int quality = 80,
  }) async {
    try {
      return await compute(
        _compressWorker,
        _CompressionParams(rawBytes, maxDimension, quality),
      );
    } catch (_) {
      return rawBytes;
    }
  }

  static Uint8List _compressWorker(_CompressionParams params) {
    final original = img.decodeImage(params.bytes);
    if (original == null) return params.bytes;

    img.Image resized = original;
    if (original.width > params.maxDimension || original.height > params.maxDimension) {
      if (original.width >= original.height) {
        resized = img.copyResize(original, width: params.maxDimension);
      } else {
        resized = img.copyResize(original, height: params.maxDimension);
      }
    }

    final compressed = img.encodeJpg(resized, quality: params.quality);
    return Uint8List.fromList(compressed);
  }
}

class _CompressionParams {
  const _CompressionParams(this.bytes, this.maxDimension, this.quality);
  final Uint8List bytes;
  final int maxDimension;
  final int quality;
}
