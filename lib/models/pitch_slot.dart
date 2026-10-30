/// One bookable block on a field's day grid.
///
/// Times stay as the instants Postgres returns; the UI renders them with
/// `addisWall`, so a block never shifts with the device timezone.
class PitchSlot {
  final DateTime start;
  final DateTime end;
  final bool isBooked;

  const PitchSlot({
    required this.start,
    required this.end,
    required this.isBooked,
  });

  factory PitchSlot.fromJson(Map<String, dynamic> json) {
    return PitchSlot(
      start: DateTime.parse(json['slot_start'] as String),
      end: DateTime.parse(json['slot_end'] as String),
      isBooked: json['is_booked'] as bool? ?? false,
    );
  }

  int get lengthMinutes => end.difference(start).inMinutes;

  bool get isPast => !start.isAfter(DateTime.now());

  bool get isAvailable => !isBooked && !isPast;
}
