import 'dart:ui';

/// Shared by the world and the shop so the chosen item keeps the same colors.
abstract final class HabitatPalette {
  static ColorFilter? forSprite(String key) {
    if (key.startsWith('rock_')) return stone;
    if ([
      'tree_',
      'plant_',
      'grass',
      'log_',
      'stump_',
      'crops_',
    ].any(key.startsWith)) {
      return foliage;
    }
    return null;
  }

  static const foliage = ColorFilter.matrix([
    .4171,
    .1403,
    .4093,
    0,
    0,
    .1098,
    .299,
    .569,
    0,
    0,
    .2558,
    -.8953,
    1.5395,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
  static const stone = ColorFilter.matrix([
    .3894,
    .1537,
    .4124,
    0,
    0,
    .2499,
    .4421,
    .2636,
    0,
    0,
    .3767,
    -.3186,
    .8419,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
}
