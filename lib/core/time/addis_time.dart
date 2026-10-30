/// Addis Ababa keeps EAT (UTC+3) all year — no daylight saving — so a fixed
/// offset is exact and the app never depends on the device timezone.
const Duration addisOffset = Duration(hours: 3);

/// Short label shown next to clock times.
const String eatLabel = 'EAT';

/// An instant rendered as Addis wall-clock time.
///
/// The result is flagged UTC so `DateFormat` prints Addis hours on any device
/// instead of converting again to the phone's timezone.
DateTime addisWall(DateTime instant) => instant.toUtc().add(addisOffset);

/// The Addis calendar day that [instant] falls on, at midnight.
DateTime addisDate(DateTime instant) {
  final wall = addisWall(instant);
  return DateTime.utc(wall.year, wall.month, wall.day);
}

/// The instant at which [hour]:[minute] Addis wall-clock on [date] happens.
DateTime addisInstant(DateTime date, {int hour = 0, int minute = 0}) {
  return DateTime.utc(
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  ).subtract(addisOffset);
}

/// Today's date in Addis, at midnight.
DateTime addisToday() => addisDate(DateTime.now());
