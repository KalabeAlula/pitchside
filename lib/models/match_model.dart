class MatchOverview {
  final String id;
  final String pitchId;
  final String pitchName;
  final String subCityId;
  final String subCityName;
  final double? latitude;
  final double? longitude;
  final String organizerId;
  final String organizerName;
  final int teamSize;
  final int maxPlayers;
  final int currentPlayers;
  final int spotsLeft;
  final DateTime startsAt;
  final DateTime endsAt;
  final double pricePerPlayer;
  final String status;
  final String? notes;

  const MatchOverview({
    required this.id,
    required this.pitchId,
    required this.pitchName,
    required this.subCityId,
    required this.subCityName,
    required this.latitude,
    required this.longitude,
    required this.organizerId,
    required this.organizerName,
    required this.teamSize,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.spotsLeft,
    required this.startsAt,
    required this.endsAt,
    required this.pricePerPlayer,
    required this.status,
    this.notes,
  });

  bool get isFull => spotsLeft <= 0;

  String get formatLabel => '${teamSize}v$teamSize';

  factory MatchOverview.fromJson(Map<String, dynamic> json) {
    return MatchOverview(
      id: json['id'] as String,
      pitchId: json['pitch_id'] as String,
      pitchName: json['pitch_name'] as String,
      subCityId: json['sub_city_id'] as String,
      subCityName: json['sub_city_name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      organizerId: json['organizer_id'] as String,
      organizerName: json['organizer_name'] as String,
      teamSize: json['team_size'] as int,
      maxPlayers: json['max_players'] as int,
      currentPlayers: json['current_players'] as int,
      spotsLeft: json['spots_left'] as int,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      pricePerPlayer: (json['price_per_player'] as num).toDouble(),
      status: json['status'] as String,
      notes: json['notes'] as String?,
    );
  }
}
