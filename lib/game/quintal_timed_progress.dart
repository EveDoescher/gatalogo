/// Read-only projection of a server deadline; never collects a reward.
class QuintalTimedProgress {
  QuintalTimedProgress({
    required this.end,
    this.start,
    this.stopAt,
    this.pauseReason,
    this.expiresReason,
  });
  final DateTime end;
  final DateTime? start;
  final DateTime? stopAt;
  final String? pauseReason, expiresReason;

  static QuintalTimedProgress? fromRow(Map<String, dynamic> row) {
    final resident = row['production_progress'];
    if (resident is Map) {
      final observed = DateTime.tryParse(
        resident['observed_at']?.toString() ?? '',
      );
      final cycle = (resident['cycle_seconds'] as num?)?.toDouble();
      final elapsed = (resident['elapsed_seconds'] as num?)?.toDouble();
      if (observed != null && cycle != null && cycle > 0 && elapsed != null) {
        final begin = observed.subtract(
          Duration(milliseconds: (elapsed.clamp(0, cycle) * 1000).round()),
        );
        final pause = resident['pause_reason']?.toString();
        return QuintalTimedProgress(
          start: begin,
          end: begin.add(Duration(milliseconds: (cycle * 1000).round())),
          stopAt: pause != null
              ? observed
              : DateTime.tryParse(resident['active_until']?.toString() ?? ''),
          pauseReason: pause,
          expiresReason: resident['expires_reason']?.toString(),
        );
      }
    }
    final end = DateTime.tryParse(
      (row['ready_at'] ?? row['next_ready_at'])?.toString() ?? '',
    );
    if (end == null) return null;
    return QuintalTimedProgress(
      end: end,
      start: DateTime.tryParse(row['started_at']?.toString() ?? ''),
    );
  }

  bool queued(DateTime now) => start?.isAfter(now) == true;

  double? fraction(DateTime now) {
    final begin = start;
    if (begin == null || !end.isAfter(begin)) return null;
    final effective = stopAt != null && now.isAfter(stopAt!) ? stopAt! : now;
    return (effective.difference(begin).inMilliseconds /
            end.difference(begin).inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String? pauseAt(DateTime now) =>
      pauseReason ??
      (stopAt != null && !now.isBefore(stopAt!) && stopAt!.isBefore(end)
          ? expiresReason
          : null);

  String label(DateTime now) {
    final reason = pauseAt(now);
    if (reason != null) {
      return switch (reason) {
        'needs_food' => 'Sem comida',
        'needs_water' => 'Sem água',
        'full' => 'Recolher',
        _ => 'Pausado',
      };
    }
    final until = queued(now) ? start! : end;
    final milliseconds = until.difference(now).inMilliseconds;
    final seconds = milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
    return queued(now) ? 'Fila · $time' : time;
  }
}
