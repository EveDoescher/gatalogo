import 'package:flutter/material.dart';

/// Shared water, reflection and original model treatment for the garden palette.
class HabitatRiverPalette {
  static const deep = Color(0xFF73998D);
  static const shallow = Color(0xFF91B9A5);
  static const middle = Color(0xFF80A797);
  static const ripple = Color(0x609FCEC0);
  static const fishTint = Color(0x906FA799);
  static const fishVeil = Color(0x287CAEA0);

  // Preserve the model relief while mapping mint grass, cyan water and orange
  // earth into the surrounding grass, sage water and warm brown bank colors.
  static const banks = ColorFilter.matrix([
    .111070,
    1.964472,
    -1.526098,
    0,
    0,
    -.067761,
    1.562056,
    -.815654,
    0,
    0,
    .049608,
    .414259,
    .181707,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
}
