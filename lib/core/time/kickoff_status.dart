import 'addis_time.dart';

/// Where a kickoff sits relative to now, in Addis time.
enum KickoffPhase { started, soon, today, tomorrow, later }

/// The chip label for one upcoming kickoff, plus the countdown that feeds the
/// late-cancel warning.
class KickoffStatus {
  const KickoffStatus({required this.phase, required this.remaining});

  final KickoffPhase phase;
  final Duration remaining;

  /// Same three-hour window the database penalises a confirmed drop-out in.
  bool get isLateCancelWindow =>
      phase == KickoffPhase.started || phase == KickoffPhase.soon;

  String get chipLabel => switch (phase) {
    KickoffPhase.started => 'Kickoff passed',
    KickoffPhase.soon => 'In $remainingLabel',
    KickoffPhase.today => 'Today',
    KickoffPhase.tomorrow => 'Tomorrow',
    KickoffPhase.later => 'Confirmed',
  };

  /// Remaining time as '2h 15m' or '43 min'.
  String get remainingLabel {
    final minutes = (remaining.inSeconds / 60).ceil();
    if (minutes <= 1) return '1 min';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  static KickoffStatus at(DateTime startsAt, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final remaining = startsAt.difference(current);
    if (remaining <= Duration.zero) {
      return KickoffStatus(phase: KickoffPhase.started, remaining: remaining);
    }
    final phase = remaining <= const Duration(hours: 3)
        ? KickoffPhase.soon
        : _dayPhase(startsAt, current);
    return KickoffStatus(phase: phase, remaining: remaining);
  }

  static KickoffPhase _dayPhase(DateTime startsAt, DateTime now) {
    final kickoffDay = addisDate(startsAt);
    final today = addisDate(now);
    if (kickoffDay == today) return KickoffPhase.today;
    if (kickoffDay == today.add(const Duration(days: 1))) {
      return KickoffPhase.tomorrow;
    }
    return KickoffPhase.later;
  }
}

/// True once giving up a confirmed spot falls inside the three-hour window the
/// reliability rule penalises. The database counts the same window.
bool isLateCancelWindow(DateTime startsAt, {DateTime? now}) =>
    !(now ?? DateTime.now()).isBefore(
      startsAt.subtract(const Duration(hours: 3)),
    );
