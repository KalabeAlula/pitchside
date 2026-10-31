/// One scheduled match the player still holds a confirmed spot in.
class UpcomingMatch {
  final String id;
  final String pitchId;
  final String pitchName;
  final String subCityName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? team;

  const UpcomingMatch({
    required this.id,
    required this.pitchId,
    required this.pitchName,
    required this.subCityName,
    required this.startsAt,
    required this.endsAt,
    required this.team,
  });

  factory UpcomingMatch.fromJson(Map<String, dynamic> json) {
    return UpcomingMatch(
      id: json['id'] as String,
      pitchId: json['pitch_id'] as String,
      pitchName: json['pitch_name'] as String,
      subCityName: json['sub_city_name'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      team: json['team'] as String?,
    );
  }
}
