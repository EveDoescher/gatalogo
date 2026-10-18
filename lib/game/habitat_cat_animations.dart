import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

enum HabitatCatClip {
  idle('idle'),
  walk('walk'),
  run('run'),
  eat('eat'),
  play('play'),
  dance('dance'),
  happy('gesture-positive'),
  upset('gesture-negative');

  const HabitatCatClip(this.asset);
  final String asset;
}

/// Atlases are shared by every cat; each clip is decoded only when requested.
class HabitatCatAnimations {
  HabitatCatAnimations({this.path = 'assets/habitat/cat'});
  HabitatCatAnimations.coat(String id, HabitatCatAnimations geometry)
    : path = 'assets/habitat/cat',
      _imagePrefix = 'assets/habitat/cat_coats/${id}__',
      _geometry = geometry;
  final String path;
  String? _imagePrefix;
  HabitatCatAnimations? _geometry;
  final Map<HabitatCatClip, Future<void>> _loading = {};
  final Map<HabitatCatClip, (ui.Image, ui.Image)> _atlases = {};
  late Map<String, dynamic> _data;
  Future<void>? _initialization;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    for (final atlas in _atlases.values) {
      atlas.$1.dispose();
      if (_geometry == null) atlas.$2.dispose();
    }
    _atlases.clear();
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (_geometry case final geometry?) {
      await geometry.initialize();
      _data = geometry._data;
      return;
    }
    _data = jsonDecode(
      await rootBundle.loadString('$path/animations.json'),
    ) as Map<String, dynamic>;
  }

  double get restHeight => (_data['restHeight'] as num).toDouble();

  Future<ui.Image> _image(String name) async {
    final bytes = await rootBundle.load(
      _imagePrefix == null ? '$path/$name.png' : '$_imagePrefix$name.png',
    );
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> preload(HabitatCatClip clip) {
    if (_disposed) return Future.value();
    return _loading.putIfAbsent(clip, () async {
      await initialize();
      if (_geometry case final geometry?) {
        await geometry.preload(clip);
        final image = await _image(clip.asset);
        if (_disposed) {
          image.dispose();
        } else {
          _atlases[clip] = (image, geometry._atlases[clip]!.$2);
        }
        return;
      }
      final images = await Future.wait([
        _image(clip.asset),
        _image('${clip.asset}-shadow'),
      ]);
      if (_disposed) {
        for (final image in images) {
          image.dispose();
        }
      } else {
        _atlases[clip] = (images[0], images[1]);
      }
    });
  }

  HabitatCatFrame? frame(HabitatCatClip clip, double time, int direction) {
    if (_disposed) return null;
    final atlas = _atlases[clip];
    if (atlas == null) return null;
    final definition = _data['clips'][clip.asset] as Map;
    final count = definition['count'] as int;
    final duration = (definition['duration'] as num).toDouble();
    final index = ((time % duration) / duration * count).floor().clamp(
      0,
      count - 1,
    );
    final size = (_data['size'] as num).toDouble();
    final origin = _data['origin'] as List;
    final bounds =
        definition['bounds'][(direction % 4) * count + index] as List;
    return HabitatCatFrame(
      image: atlas.$1,
      shadow: atlas.$2,
      source: ui.Rect.fromLTWH(
        index * size,
        (direction % 4) * size,
        size,
        size,
      ),
      origin: ui.Offset(
        (origin[0] as num).toDouble(),
        (origin[1] as num).toDouble(),
      ),
      visible: ui.Rect.fromLTRB(
        (bounds[0] as num).toDouble(),
        (bounds[1] as num).toDouble(),
        (bounds[2] as num).toDouble(),
        (bounds[3] as num).toDouble(),
      ),
    );
  }
}

class HabitatCatFrame {
  const HabitatCatFrame({
    required this.image,
    required this.shadow,
    required this.source,
    required this.origin,
    required this.visible,
  });

  final ui.Image image;
  final ui.Image shadow;
  final ui.Rect source;
  final ui.Offset origin;
  final ui.Rect visible;

  ui.Rect bounds(ui.Offset ground, double scale) => ui.Rect.fromLTWH(
    ground.dx + (visible.left - origin.dx) * scale,
    ground.dy + (visible.top - origin.dy) * scale,
    visible.width * scale,
    visible.height * scale,
  );

  void paint(
    ui.Canvas canvas,
    ui.Offset ground,
    double scale, {
    bool groundShadow = false,
    ui.Color? tint,
  }) {
    final destination = ui.Rect.fromLTWH(
      ground.dx - origin.dx * scale,
      ground.dy - origin.dy * scale,
      source.width * scale,
      source.height * scale,
    );
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    if (!groundShadow && tint != null) {
      paint.colorFilter = ui.ColorFilter.mode(tint, ui.BlendMode.modulate);
    }
    canvas.drawImageRect(
      groundShadow ? shadow : image,
      source,
      destination,
      paint,
    );
  }
}
