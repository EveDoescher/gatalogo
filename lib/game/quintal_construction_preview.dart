/// Presentation of the existing server capacities; never unlocks slots.
String? quintalCapacityChange(String kind, int current, int target) {
  int capacity(int level) => level <= 0
      ? 0
      : switch (kind) {
          'garden' => level.clamp(1, 3) * 4,
          'coop' => level.clamp(1, 2) * 2,
          'pasture' => level.clamp(1, 2),
          'kitchen' => level.clamp(1, 2) * 2,
          _ => 0,
        };
  final label = switch (kind) {
    'garden' => 'Canteiros',
    'coop' => 'Galinhas',
    'pasture' => 'Vacas',
    'kitchen' => 'Lugares na fila',
    _ => null,
  };
  if (label == null || target <= current) return null;
  return '$label: de ${capacity(current)} para ${capacity(target)}';
}
