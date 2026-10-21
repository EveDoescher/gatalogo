import 'package:catlogue/formatters/app_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capture dates retain their supplied calendar and padded clock', () {
    expect(
      AppDates.captureDateTime(DateTime.utc(2024, 2, 29, 3, 4)),
      '29 fev. 2024 às 03:04',
    );
    expect(AppDates.albumDate(DateTime(2026, 12, 31)), '31 dez. 2026');
  });
  test('chat day labels cross month and year boundaries', () {
    final now = DateTime(2026, 1, 1, 0, 5);
    expect(AppDates.chatDay(now, now: now), 'Hoje');
    expect(AppDates.chatDay(DateTime(2025, 12, 31, 23), now: now), 'Ontem');
    expect(AppDates.chatDay(DateTime(2025, 12, 30), now: now), '30 de Dez');
    expect(
      AppDates.lastSeen(DateTime(2025, 12, 31, 23, 7), now: now),
      'ontem às 23:07',
    );
  });
  test('chat groups timestamps by local calendar day', () {
    final first = DateTime(2026, 10, 21, 0, 1);
    expect(AppDates.isDifferentLocalDay(first, first.toUtc()), isFalse);
    expect(
      AppDates.isDifferentLocalDay(first, DateTime(2026, 10, 20, 23, 59)),
      isTrue,
    );
  });
}
