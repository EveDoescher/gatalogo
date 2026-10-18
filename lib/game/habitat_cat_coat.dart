/// Stable, approximate appearances based on the detector's existing taxonomy.
/// No random skin, new breed inference, or change to the registered analysis.
abstract final class HabitatCatCoat {
  static String? _knownColor(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'preto' || 'black' => 'black',
        'branco' || 'white' => 'white',
        'cinza' || 'gray' || 'grey' => 'gray',
        'laranja' || 'orange' || 'ruivo' => 'orange',
        'marrom' || 'brown' => 'brown',
        'creme' || 'cream' => 'cream',
        _ => null,
      };
  static String color(String? value) => _knownColor(value) ?? 'gray';

  static String resolve({
    String? primaryColor,
    String? coatType,
    List<String> colors = const [],
  }) {
    final observed = colors.map(_knownColor).whereType<String>().toList();
    final knownBase = _knownColor(primaryColor) ?? observed.firstOrNull;
    final base = knownBase ?? 'gray';
    final accents = observed.where((c) => c != base).toList();
    final pattern = coatType?.trim().toLowerCase();
    final colored = base == 'white'
        ? accents.where((c) => c != 'white').firstOrNull ?? 'black'
        : base;
    switch (pattern) {
      case 'rajado':
      case 'tabby':
        return 'tabby_${colored == 'white' ? 'gray' : colored}';
      case 'bicolor':
        return base == 'white'
            ? 'bicolor_white_$colored'
            : 'bicolor_${base}_white';
      case 'tuxedo':
        return 'tuxedo_$colored';
      case 'tricolor':
      case 'calico':
        if (base == 'black') return 'calico_dark';
        return (base == 'gray' ||
                base == 'cream' ||
                (accents.contains('gray') && !accents.contains('black')))
            ? 'calico_dilute'
            : 'calico';
      case 'escaminha':
      case 'tortoiseshell':
        if (base == 'gray' || base == 'cream' || accents.contains('gray')) {
          return 'tortie_dilute';
        }
        return base == 'brown' ? 'tortie_brown' : 'tortie';
      case 'colorpoint':
      case 'siamês':
      case 'siames':
        final dark = [
          ?knownBase,
          ...accents,
        ].where((c) => c == 'black' || c == 'brown' || c == 'gray').firstOrNull;
        return 'point_${dark ?? 'brown'}';
      default:
        return 'solid_$base';
    }
  }

  static String preview(String coat) =>
      'assets/habitat/cat_coats/${coat}__preview.png';
}
