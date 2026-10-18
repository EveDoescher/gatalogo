/// Presentation of a confirmed meal. Quantities always come from the server.
class QuintalCatMeal {
  QuintalCatMeal._(this.data, this.at, this.eventId);
  final Map data;
  final DateTime at;
  final String eventId;

  static QuintalCatMeal? fromCare(Map care) {
    final data = care['last_reaction'];
    if (data is! Map || !['meal', 'refused'].contains(data['kind'])) {
      return null;
    }
    final at = DateTime.tryParse(data['at']?.toString() ?? '');
    if (at == null) return null;
    return QuintalCatMeal._(
      data,
      at,
      data['event_id']?.toString() ?? at.toIso8601String(),
    );
  }

  bool get refused => data['kind'] == 'refused';
  String get recipe => data['recipe']?.toString() ?? 'basic';
  int? get preference => (data['preference'] as num?)?.toInt();
  int? get nextPreference => (data['next_preference'] as num?)?.toInt();
  int? get before => (data['portions_before'] as num?)?.toInt();
  int? get after => (data['portions_after'] as num?)?.toInt();
  bool recent(DateTime now) =>
      !at.isAfter(now) && now.difference(at) < const Duration(seconds: 90);

  bool canShowPortions(Map care) {
    final served = DateTime.tryParse(care['served_at']?.toString() ?? '');
    return before != null &&
        after != null &&
        before! <= 2 &&
        after! >= 0 &&
        before! > after! &&
        care['portions'] == after &&
        care['recipe'] == recipe &&
        served != null &&
        !served.isAfter(at);
  }

  String get reactionText {
    if (refused) {
      final lost = (data['lost'] as num?)?.toInt() ?? 1;
      return lost == 1
          ? 'Recusou · 1 porção perdida.'
          : 'Recusou · $lost porções perdidas.';
    }
    return switch (preference) {
      1 => 'Comeu, mas não é fã.',
      2 => 'Aceitou a refeição.',
      4 => 'Gostou da refeição!',
      5 => 'Gostou muito!',
      6 => 'É a favorita!',
      _ => 'Comeu a refeição.',
    };
  }

  String? get tasteChange =>
      !refused &&
          preference != null &&
          nextPreference != null &&
          preference != nextPreference
      ? 'Gosto mudou de ${tasteName(preference)} para ${tasteName(nextPreference)}.'
      : null;

  static String tasteName(int? value) => switch (value) {
    0 => 'Odeia',
    1 => 'Não é fã',
    2 => 'Aceita',
    3 => 'Normal',
    4 => 'Gosta',
    5 => 'Gosta muito',
    6 => 'Favorita',
    _ => 'Desconhecido',
  };
}

DateTime? quintalNextAppetite(Map care) =>
    DateTime.tryParse(care['next_appetite_at']?.toString() ?? '') ??
    DateTime.tryParse(care['last_meal_at']?.toString() ?? '')
        ?.add(const Duration(hours: 12));

String quintalAppetiteText(Map care, DateTime serverNow) {
  final at = quintalNextAppetite(care);
  if (at == null || !at.isAfter(serverNow)) return 'Pronto para uma refeição';
  final local = at.toLocal();
  return 'Próximo apetite às ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
