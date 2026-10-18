import 'habitat_service.dart';

/// Quantities in distinct places. Stock is already net of reservations.
class QuintalInventoryEntry {
  QuintalInventoryEntry(this.id);
  final String id;
  int available = 0, reserved = 0, preparing = 0, served = 0, ready = 0;
  final Set<String> collectionSpaces = {};
  bool get visible => available + reserved + preparing + served + ready > 0;
}

Map<String, QuintalInventoryEntry> quintalInventory(HabitatService h) {
  final result = <String, QuintalInventoryEntry>{};
  QuintalInventoryEntry entry(String id) =>
      result.putIfAbsent(id, () => QuintalInventoryEntry(id));
  int quantity(dynamic value) =>
      value is num ? value.toInt().clamp(0, 1 << 30) : 0;
  bool ready(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date != null && !date.isAfter(h.serverNow);
  }

  void awaiting(String id, int count, String space) {
    if (count <= 0) return;
    entry(id).ready += count;
    entry(id).collectionSpaces.add(space);
  }

  for (final stock in h.productionStock.entries) {
    entry(stock.key).available = quantity(stock.value);
  }
  for (final task in h.productionRows('tasks')) {
    if (!{'active', 'ready'}.contains(task['status'])) continue;
    final done = task['status'] == 'ready' || ready(task['ready_at']);
    if (!done) {
      for (final input in (task['inputs'] as Map? ?? const {}).entries) {
        entry(input.key.toString()).reserved += quantity(input.value);
      }
    }
    for (final output in (task['outputs'] as Map? ?? const {}).entries) {
      final id = output.key.toString(), count = quantity(output.value);
      if (done) {
        awaiting(id, count, task['kind'] == 'cook' ? 'kitchen' : 'market');
      } else {
        entry(id).preparing += count;
      }
    }
  }
  for (final cat in h.productionRows('cats')) {
    final recipe = cat['recipe'];
    if (recipe is String && recipe != 'basic') {
      entry('ration:$recipe').served += quantity(cat['portions']);
    }
  }
  final crops = {
    for (final row in h.productionRows('crops', catalog: true)) row['id']: row,
  };
  for (final plot in h.productionRows('plots')) {
    final crop = plot['crop'];
    if (crop is String && ready(plot['ready_at'])) {
      awaiting(crop, quantity(crops[crop]?['yield']), 'garden');
    }
  }
  for (final resident in h.productionRows('residents')) {
    final kind = resident['kind'];
    if (kind == 'orchard') {
      for (final tree in resident['animals'] as List? ?? const []) {
        final slot = tree['slot'];
        if (slot is num) {
          awaiting(
            slot.toInt().isEven ? 'apple' : 'pear',
            quantity(tree['ready']),
            'orchard',
          );
        }
      }
    } else if (kind == 'coop' || kind == 'pasture') {
      awaiting(
        kind == 'coop' ? 'egg' : 'milk',
        quantity(resident['ready']),
        kind,
      );
    }
  }
  result.removeWhere((_, value) => !value.visible);
  return result;
}
