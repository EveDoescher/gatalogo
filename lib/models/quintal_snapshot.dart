/// Typed access to server/cache production payloads. Unknown fields round-trip.
class QuintalSnapshot {
  QuintalSnapshot(Map<String, dynamic> value) : _value = value;
  final Map<String, dynamic> _value;
  Map<String, dynamic> get wire => _value;
  DateTime? get serverNow =>
      DateTime.tryParse(_value['server_now']?.toString() ?? '');
  String get calendarDay => _value['calendar_day']?.toString() ?? '';
  Map<String, int> get stock => {
    if (_value['stock'] case final Map values)
      for (final entry in values.entries)
        if (entry.value is num)
          entry.key.toString(): (entry.value as num).toInt(),
  };
  List<Map<String, dynamic>> rows(String key, {bool catalog = false}) {
    final source = catalog ? _value['catalog'] : _value;
    if (source is! Map || source[key] is! List) return [];
    return [
      for (final row in source[key] as List)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  int facilityLevel(String kind) =>
      (rows('facilities').where((v) => v['kind'] == kind).firstOrNull?['level']
              as num?)
          ?.toInt() ??
      0;
  Map<String, dynamic> cat(String id) =>
      rows('cats').where((v) => v['cat_id'] == id).firstOrNull ?? {};
  int? preference(String id, String recipe) =>
      (rows('preferences')
                  .where((v) => v['cat_id'] == id && v['recipe'] == recipe)
                  .firstOrNull?['level']
              as num?)
          ?.toInt();
}
