import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Loads only the sprite orientations used in the current scene.
class HabitatSprites {
  static const _nature = 'assets/3d_assets/kenney_nature-kit/Isometric';
  static const _rendered = 'assets/habitat';
  static const _icons = 'assets/3d_assets/kenney_mini-dungeon/Previews';

  final Map<String, Future<ui.Image>> _images = {};
  final Map<String, Future<ui.Image>> _preparing = {};
  final Map<String, HabitatSpriteLighting> _lighting = {};
  Map<String, ui.Rect>? _bounds;
  Map<String, dynamic> _lightingData = {};
  Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final raw = jsonDecode(
      await rootBundle.loadString('$_nature/habitat_bounds.json'),
    ) as Map;
    _bounds = {
      for (final entry in raw.entries)
        entry.key.toString(): ui.Rect.fromLTWH(
          (entry.value[0] as num).toDouble(),
          (entry.value[1] as num).toDouble(),
          (entry.value[2] as num).toDouble(),
          (entry.value[3] as num).toDouble(),
        ),
    };
    _lightingData = jsonDecode(
      await rootBundle.loadString('$_nature/habitat_lighting.json'),
    ) as Map<String, dynamic>;
  }

  String keyFor(String sprite, int rotation) {
    if (sprite.startsWith('building-type-') ||
        sprite == 'coin' ||
        sprite == 'chest' ||
        sprite == 'animal-cat') {
      return sprite;
    }
    return '${sprite}_${['NE', 'SE', 'SW', 'NW'][rotation % 4]}';
  }

  ui.Rect bounds(String key) => _bounds![key]!;

  ui.Offset groundOrigin(String key) {
    final data = _lightingData[key] as Map?;
    if (data == null) return const ui.Offset(256, 315.5);
    final origin = data['origin'] as List;
    return ui.Offset(
      (origin[0] as num).toDouble(),
      (origin[1] as num).toDouble(),
    );
  }

  ui.Rect placedBounds(String key, ui.Offset ground, double scale) {
    final source = bounds(key);
    final origin = groundOrigin(key) + groundCenter(key);
    return ui.Rect.fromLTWH(
      ground.dx + (source.left - origin.dx) * scale,
      ground.dy + (source.top - origin.dy) * scale,
      source.width * scale,
      source.height * scale,
    );
  }

  /// Horizontal mesh center, projected onto the ground (not the PNG center).
  ui.Offset groundCenter(String key) {
    final center = (_lightingData[key] as Map?)?['groundCenter'] as List?;
    if (center == null) return ui.Offset.zero;
    return ui.Offset(
      (center[0] as num).toDouble(),
      (center[1] as num).toDouble(),
    );
  }

  double fitScale(
    String key,
    double preferred,
    double tileWidth,
    int width,
    int height,
  ) {
    final size = (_lightingData[key] as Map?)?['groundSize'] as List?;
    if (size == null) return preferred;
    final x = (size[0] as num).toDouble();
    final y = (size[1] as num).toDouble();
    return math.min(
      preferred,
      math.min(width * tileWidth * 0.48 / x, height * tileWidth * 0.48 / y),
    );
  }

  void paintSprite(
    ui.Canvas canvas,
    String key,
    ui.Rect destination,
    ui.Paint paint,
  ) {
    final image = cached(key);
    if (image == null) return;
    final source = bounds(key);
    final data = _lightingData[key] as Map?;
    final heightScale = (data?['heightScale'] as num?)?.toDouble();
    if (heightScale == null) {
      canvas.drawImageRect(image, source, destination, paint);
      return;
    }
    // Raise the fence posts without changing the angle or position of their feet.
    final line = data!['groundLine'] as List;
    final slope = (line[0] as num).toDouble();
    final intercept = (line[1] as num).toDouble();
    final scale = destination.width / source.width;
    final origin =
        destination.topLeft + (groundOrigin(key) - source.topLeft) * scale;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.transform(
      Float64List.fromList([
        1,
        (1 - heightScale) * slope,
        0,
        0,
        0,
        heightScale,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        (1 - heightScale) * intercept * scale,
        0,
        1,
      ]),
    );
    canvas.translate(-origin.dx, -origin.dy);
    canvas.drawImageRect(image, source, destination, paint);
    canvas.restore();
  }

  void drawShadow(
    ui.Canvas canvas,
    String key,
    ui.Offset ground,
    double scale,
  ) {
    _lighting[key]?.draw(canvas, ground - groundCenter(key) * scale, scale);
  }

  Future<ui.Image> load(String key) => _images.putIfAbsent(key, () async {
    await initialize();
    final path = key == 'animal-cat' || key.startsWith('building-type-')
        ? '$_rendered/$key.png'
        : key == 'coin' || key == 'chest'
        ? '$_icons/$key.png'
        : '$_nature/$key.png';
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  });

  Future<void> preload(Iterable<String> keys) async {
    await Future.wait(keys.map(load));
  }

  ui.Image? cached(String key) {
    final future = _images[key];
    if (future == null) return null;
    // Completeness is tracked separately so render never awaits a Future.
    return _ready[key];
  }

  final Map<String, ui.Image> _ready = {};

  Future<ui.Image> ready(String key) => _preparing.putIfAbsent(key, () async {
    final image = await load(key);
    final data = _lightingData[key] as Map?;
    if (data != null) {
      _lighting[key] = await HabitatSpriteLighting.bake(data);
    }
    _ready[key] = image;
    return image;
  });

  Future<void> preloadReady(Iterable<String> keys) async {
    await Future.wait(keys.map(ready));
  }
}

/// Ground shadows are rasterized once from the offline mesh projection.
/// The scene only scales cached images, including during pan and pinch gestures.
class HabitatSpriteLighting {
  HabitatSpriteLighting._(this.image, this.bounds);

  final ui.Image image;
  final ui.Rect bounds;

  static Future<HabitatSpriteLighting> bake(Map data) async {
    ui.Path pathFrom(List polygons) {
      final path = ui.Path();
      for (final polygon in polygons.cast<List>()) {
        path.moveTo(
          (polygon[0] as num).toDouble(),
          (polygon[1] as num).toDouble(),
        );
        for (var i = 2; i < polygon.length; i += 2) {
          path.lineTo(
            (polygon[i] as num).toDouble(),
            (polygon[i + 1] as num).toDouble(),
          );
        }
        path.close();
      }
      return path;
    }

    final shadow = pathFrom(data['shadow'] as List);
    final contact = pathFrom(data['contact'] as List);
    final area = shadow
        .getBounds()
        .expandToInclude(contact.getBounds())
        .inflate(7);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..translate(-area.left, -area.top);
    canvas.drawPath(
      shadow,
      ui.Paint()
        ..color = const ui.Color(0x38344C2B)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.2),
    );
    canvas.drawPath(
      contact,
      ui.Paint()
        ..color = const ui.Color(0x33344C2B)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.3),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(area.width.ceil(), area.height.ceil());
    picture.dispose();
    return HabitatSpriteLighting._(
      image,
      ui.Rect.fromLTWH(
        area.left,
        area.top,
        image.width.toDouble(),
        image.height.toDouble(),
      ),
    );
  }

  void draw(ui.Canvas canvas, ui.Offset ground, double scale) {
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(
        ground.dx + bounds.left * scale,
        ground.dy + bounds.top * scale,
        bounds.width * scale,
        bounds.height * scale,
      ),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }
}
