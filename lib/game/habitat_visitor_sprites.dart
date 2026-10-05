import 'dart:async';

import 'habitat_cat_animations.dart';

/// Decode only visitors currently in the scene; release departing species.
class HabitatVisitorSprites {
  final Map<String, HabitatCatAnimations> _animals = {};
  final Map<String, Future<void>> _ready = {};
  bool _disposed = false;

  Future<void> prepare(String species, HabitatCatClip clip) async {
    if (_disposed) return;
    final animal = _animals.putIfAbsent(
      species,
      () => HabitatCatAnimations(path: 'assets/habitat/$species'),
    );
    final key = '$species:${clip.asset}';
    await (_ready[key] ??= () async {
      await animal.initialize();
      await animal.preload(clip);
    }());
  }

  HabitatCatFrame? frame(
    String species,
    HabitatCatClip clip,
    double time,
    int direction,
  ) => _animals[species]?.frame(clip, time, direction);
  double height(String species) => _animals[species]!.restHeight;

  void retain(Set<String> visible) {
    for (final species in _animals.keys.toList()) {
      if (visible.contains(species)) continue;
      _animals.remove(species)!.dispose();
      _ready.removeWhere((key, _) => key.startsWith('$species:'));
    }
  }

  void dispose() {
    _disposed = true;
    for (final animal in _animals.values) {
      animal.dispose();
    }
    _animals.clear();
    _ready.clear();
  }
}
