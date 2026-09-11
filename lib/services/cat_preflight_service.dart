import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class CapturePreflightResult {
  const CapturePreflightResult._({
    required this.accepted,
    this.message,
    this.usedLocalModel = false,
  });

  const CapturePreflightResult.accepted({bool usedLocalModel = false})
    : this._(accepted: true, usedLocalModel: usedLocalModel);

  const CapturePreflightResult.rejected(String message)
    : this._(accepted: false, message: message, usedLocalModel: true);

  final bool accepted;
  final String? message;
  final bool usedLocalModel;
}

class CatPreflightService {
  CatPreflightService({this._interpreter});

  static const _modelAsset = 'assets/models/cat_detector.tflite';
  static const _inputSize = 300;
  static const _maxDetections = 10;
  // O labelmap do SSD MobileNet COCO inicia em `person = 0`; logo `cat = 16`.
  static const _catClassId = 16;
  static const _minimumConfidence = 0.32;
  static const _minimumCatArea = 0.03;
  static const _secondaryCatAreaRatio = 0.45;

  Interpreter? _interpreter;

  Future<void> warmUp() async {
    try {
      await _getInterpreter();
    } on Object catch (error, stackTrace) {
      // A falha é tratada novamente durante a validação, que seguirá para a
      // API sem bloquear a pessoa caso o modelo não esteja disponível.
      debugPrint('Não foi possível preparar o pré-filtro local: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<CapturePreflightResult> validate(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        return const CapturePreflightResult.rejected(
          'Não encontramos um gato com clareza. Aproxime-se e tente outra foto.',
        );
      }

      final qualityMessage = _qualityMessage(image);
      if (qualityMessage != null) {
        return CapturePreflightResult.rejected(qualityMessage);
      }

      final rawCats = await _detectCats(image);
      final cats = _suppressOverlappingCats(rawCats);
      if (cats.isEmpty) {
        return const CapturePreflightResult.rejected(
          'Não encontramos um gato com clareza. Aproxime-se e tente outra foto.',
        );
      }

      cats.sort((first, second) => second.area.compareTo(first.area));
      final primary = cats.first;
      if (primary.area < _minimumCatArea) {
        return const CapturePreflightResult.rejected(
          'O gato está muito distante. Faça uma foto mais próxima.',
        );
      }

      if (cats.length > 1 &&
          cats[1].area / primary.area >= _secondaryCatAreaRatio) {
        return const CapturePreflightResult.rejected(
          'Encontramos mais de um gato em destaque. Fotografe um por vez.',
        );
      }

      return const CapturePreflightResult.accepted(usedLocalModel: true);
    } on Object catch (error, stackTrace) {
      // O filtro reduz chamadas desnecessárias, mas não pode impedir o uso do
      // aplicativo caso o modelo local esteja indisponível no aparelho.
      debugPrint('Pré-filtro local indisponível: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const CapturePreflightResult.accepted();
    }
  }

  String? _qualityMessage(img.Image image) {
    final preview = img.copyResize(image, width: 160);
    var luminanceSum = 0.0;
    var luminanceSquaredSum = 0.0;
    var pixelCount = 0;
    var edgeStrength = 0.0;

    for (var y = 0; y < preview.height; y++) {
      for (var x = 0; x < preview.width; x++) {
        final pixel = preview.getPixel(x, y);
        final value = 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
        luminanceSum += value;
        luminanceSquaredSum += value * value;
        pixelCount++;

        if (x > 0) {
          final left = preview.getPixel(x - 1, y);
          final leftValue = 0.2126 * left.r + 0.7152 * left.g + 0.0722 * left.b;
          edgeStrength += (value - leftValue).abs();
        }
      }
    }

    final mean = luminanceSum / pixelCount;
    final contrast = sqrt(
      max(0, luminanceSquaredSum / pixelCount - mean * mean),
    );
    final averageEdge = edgeStrength / max(1, preview.width * preview.height);

    // Limites calibrados para não rejeitar gatos pretos ou fotos com iluminação de ambiente
    if (mean < 22) {
      return 'A foto está escura ou sem contraste. Tente com mais luz.';
    }
    if (mean > 245 || contrast < 10) {
      return 'A foto está sem contraste ou estourada de luz. Tente com mais equilíbrio.';
    }
    if (averageEdge < 2.5) {
      return 'A foto está muito borrada. Segure o celular firme e tente novamente.';
    }
    return null;
  }

  img.Image _letterbox(img.Image src, int size) {
    final scale = min(size / src.width, size / src.height);
    final newW = (src.width * scale).round().clamp(1, size);
    final newH = (src.height * scale).round().clamp(1, size);

    final resized = img.copyResize(src, width: newW, height: newH);
    final canvas = img.Image(width: size, height: size);
    img.fill(canvas, color: img.ColorRgb8(128, 128, 128));

    final offsetX = (size - newW) ~/ 2;
    final offsetY = (size - newH) ~/ 2;
    img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);
    return canvas;
  }

  Future<List<_CatCandidate>> _detectCats(img.Image image) async {
    final interpreter = await _getInterpreter();
    final resized = _letterbox(image, _inputSize);
    final isQuantizedInput =
        interpreter.getInputTensor(0).type == TensorType.uint8;
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          if (isQuantizedInput) {
            return <int>[pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
          }
          return <double>[
            pixel.r / 127.5 - 1,
            pixel.g / 127.5 - 1,
            pixel.b / 127.5 - 1,
          ];
        }),
      ),
    );
    final locations = List.generate(
      1,
      (_) => List.generate(_maxDetections, (_) => List.filled(4, 0.0)),
    );
    final classes = List.generate(1, (_) => List.filled(_maxDetections, 0.0));
    final scores = List.generate(1, (_) => List.filled(_maxDetections, 0.0));
    // O SSD MobileNet devolve `num_detections` com shape [1], não [1, 1].
    final count = List.filled(1, 0.0);

    interpreter.runForMultipleInputs(
      [input],
      {0: locations, 1: classes, 2: scores, 3: count},
    );

    final candidates = <_CatCandidate>[];
    final resultCount = min<int>(_maxDetections, count[0].round());
    for (var index = 0; index < resultCount; index++) {
      if (classes[0][index].round() != _catClassId ||
          scores[0][index] < _minimumConfidence) {
        continue;
      }

      final location = locations[0][index];
      final ymin = location[0].clamp(0.0, 1.0).toDouble();
      final xmin = location[1].clamp(0.0, 1.0).toDouble();
      final ymax = location[2].clamp(0.0, 1.0).toDouble();
      final xmax = location[3].clamp(0.0, 1.0).toDouble();

      final width = (xmax - xmin).clamp(0.0, 1.0);
      final height = (ymax - ymin).clamp(0.0, 1.0);
      final area = width * height;

      candidates.add(
        _CatCandidate(
          ymin: ymin,
          xmin: xmin,
          ymax: ymax,
          xmax: xmax,
          score: scores[0][index],
          area: area,
        ),
      );
    }
    return candidates;
  }

  List<_CatCandidate> _suppressOverlappingCats(List<_CatCandidate> candidates) {
    if (candidates.length <= 1) return candidates;

    // Ordena por confiança decrescente
    final sorted = List<_CatCandidate>.from(candidates)
      ..sort((a, b) => b.score.compareTo(a.score));

    final distinctCats = <_CatCandidate>[];

    for (final candidate in sorted) {
      var isDuplicate = false;
      for (final existing in distinctCats) {
        // Se houver IoU acima de 0.25 ou uma caixa estiver > 50% contida na outra,
        // trata-se do MESMO gato detectado com caixas parciais/duplicadas.
        if (candidate.iouWith(existing) > 0.25 ||
            candidate.overlapRatioWith(existing) > 0.50) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        distinctCats.add(candidate);
      }
    }

    return distinctCats;
  }

  Future<Interpreter> _getInterpreter() async {
    final current = _interpreter;
    if (current != null) {
      return current;
    }
    final options = InterpreterOptions()..threads = 2;
    final loaded = await Interpreter.fromAsset(_modelAsset, options: options);
    _interpreter = loaded;
    return loaded;
  }

  void dispose() {
    _interpreter?.close();
  }
}

class _CatCandidate {
  const _CatCandidate({
    required this.ymin,
    required this.xmin,
    required this.ymax,
    required this.xmax,
    required this.score,
    required this.area,
  });

  final double ymin;
  final double xmin;
  final double ymax;
  final double xmax;
  final double score;
  final double area;

  double iouWith(_CatCandidate other) {
    final interYmin = max(ymin, other.ymin);
    final interXmin = max(xmin, other.xmin);
    final interYmax = min(ymax, other.ymax);
    final interXmax = min(xmax, other.xmax);

    final interH = max(0.0, interYmax - interYmin);
    final interW = max(0.0, interXmax - interXmin);
    final interArea = interH * interW;

    if (interArea <= 0.0) return 0.0;

    final unionArea = area + other.area - interArea;
    if (unionArea <= 0.0) return 0.0;
    return interArea / unionArea;
  }

  double overlapRatioWith(_CatCandidate other) {
    final interYmin = max(ymin, other.ymin);
    final interXmin = max(xmin, other.xmin);
    final interYmax = min(ymax, other.ymax);
    final interXmax = min(xmax, other.xmax);

    final interH = max(0.0, interYmax - interYmin);
    final interW = max(0.0, interXmax - interXmin);
    final interArea = interH * interW;

    if (interArea <= 0.0) return 0.0;
    final minArea = min(area, other.area);
    if (minArea <= 0.0) return 0.0;
    return interArea / minArea;
  }
}
