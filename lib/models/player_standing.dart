/// The signed-in player's fair-play record: the reliability score plus the
/// public-game suspension it can trigger.
class PlayerStanding {
  const PlayerStanding({
    required this.score,
    required this.suspendedUntil,
    required this.matchesPlayed,
    required this.noShows,
  });

  /// 0–100. Starts at 100 and drops 25 per late cancellation or no-show.
  final int score;

  /// When a public-game suspension lifts. Null when the player is not banned;
  /// a past instant means the ban ran out.
  final DateTime? suspendedUntil;

  final int matchesPlayed;
  final int noShows;

  bool get isSuspended =>
      suspendedUntil != null && suspendedUntil!.isAfter(DateTime.now());

  /// An old ban that has expired. The player can join public games again even
  /// though the score itself does not climb back on its own.
  bool get suspensionEnded => suspendedUntil != null && !isSuspended;

  /// One more late cancellation or no-show would take them below 50.
  bool get isAtRisk => score >= 50 && score < 75;

  factory PlayerStanding.fromJson(Map<String, dynamic> json) {
    final until = json['suspended_until'] as String?;
    return PlayerStanding(
      score: (json['reliability_score'] as num).toInt(),
      suspendedUntil: until == null ? null : DateTime.parse(until),
      matchesPlayed: (json['matches_played'] as num).toInt(),
      noShows: (json['no_shows'] as num).toInt(),
    );
  }
}
