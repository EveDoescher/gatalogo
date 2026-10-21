/// Portuguese display formats shared by album, capture details, and chat.
/// Capture metadata keeps its supplied calendar; chat uses the device timezone.
abstract final class AppDates {
  static const _months = [
    'jan.',
    'fev.',
    'mar.',
    'abr.',
    'mai.',
    'jun.',
    'jul.',
    'ago.',
    'set.',
    'out.',
    'nov.',
    'dez.',
  ];
  static const _chatMonths = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  static String clock(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  static String albumDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';
  static String captureDateTime(DateTime date) =>
      '${albumDate(date)} às ${clock(date)}';
  static String chatTime(DateTime date) => clock(date.toLocal());

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static bool isDifferentLocalDay(DateTime a, DateTime b) =>
      !_sameDay(a.toLocal(), b.toLocal());
  static String _chatCalendarDate(DateTime local) =>
      '${local.day} de ${_chatMonths[local.month - 1]}';

  static String chatDay(DateTime date, {DateTime? now}) {
    final local = date.toLocal(), current = now ?? DateTime.now();
    if (_sameDay(local, current)) return 'Hoje';
    if (_sameDay(local, current.subtract(const Duration(days: 1)))) {
      return 'Ontem';
    }
    return _chatCalendarDate(local);
  }

  static String lastSeen(DateTime date, {DateTime? now}) {
    final local = date.toLocal(), current = now ?? DateTime.now();
    final day = _sameDay(local, current)
        ? 'hoje'
        : _sameDay(local, current.subtract(const Duration(days: 1)))
        ? 'ontem'
        : _chatCalendarDate(local);
    return '$day às ${clock(local)}';
  }
}
