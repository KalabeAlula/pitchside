/// One completed match the player held a confirmed spot in.
class PastMatch {
  final String id;
  final String pitchId;
  final String pitchName;
  final String subCityName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? team;

  /// Completed matches are fully marked, so this is false only for a no-show.
  final bool attended;

  const PastMatch({
    required this.id,
    required this.pitchId,
    required this.pitchName,
    required this.subCityName,
    required this.startsAt,
    required this.endsAt,
    required this.team,
    required this.attended,
  });

  factory PastMatch.fromJson(Map<String, dynamic> json) {
    return PastMatch(
      id: json['id'] as String,
      pitchId: json['pitch_id'] as String,
      pitchName: json['pitch_name'] as String,
      subCityName: json['sub_city_name'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      team: json['team'] as String?,
      attended: json['attended'] == true,
    );
  }
}
