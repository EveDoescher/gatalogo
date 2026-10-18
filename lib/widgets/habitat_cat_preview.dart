import 'package:flutter/material.dart';

import '../game/habitat_cat_coat.dart';
import '../services/habitat_service.dart';

class HabitatCatPreview extends StatelessWidget {
  const HabitatCatPreview({super.key, required this.cat, this.size = 72});
  final HabitatCat cat;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    HabitatCatCoat.preview(
      HabitatCatCoat.resolve(
        primaryColor: cat.primaryColor,
        coatType: cat.coatType,
        colors: cat.coatColors,
      ),
    ),
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: 'Gato do Quintal: ${cat.name}',
  );
}
