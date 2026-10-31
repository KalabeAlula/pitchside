import '../core/time/kickoff_status.dart';
import 'match_model.dart';

/// One roster row, joined with the player's public name.
class MatchPlayer {
  final String userId;
  final String fullName;

  /// 'A' or 'B' for confirmed players; null while waitlisted.
  final String? team;

  /// confirmed | waitlisted | left
  final String status;
  final DateTime joinedAt;

  /// Organizer's roll call: null until marked, then true (present) / false.
  final bool? attended;

  const MatchPlayer({
    required this.userId,
    required this.fullName,
    required this.team,
    required this.status,
    required this.joinedAt,
    this.attended,
  });

  bool get isConfirmed => status == 'confirmed';
  bool get isWaitlisted => status == 'waitlisted';

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.substring(0, 1);
    if (parts.length == 1) return first.toUpperCase();
    return '$first${parts.last.substring(0, 1)}'.toUpperCase();
  }

  factory MatchPlayer.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    return MatchPlayer(
      userId: json['user_id'] as String,
      fullName:
          (profile is Map ? profile['full_name'] as String? : null) ?? 'Player',
      team: json['team'] as String?,
      status: json['member_status'] as String? ?? 'confirmed',
      joinedAt: DateTime.parse(json['joined_at'] as String),
      attended: json['attended'] as bool?,
    );
  }
}

/// One match plus its full roster, seen through the current user's eyes.
class MatchDetail {
  const MatchDetail({
    required this.match,
    required this.players,
    this.currentUserId,
  });

  final MatchOverview match;
  final List<MatchPlayer> players;

  /// Null only when there is no session; the screen then shows no actions.
  final String? currentUserId;

  List<MatchPlayer> get teamA => _confirmedOn('A');
  List<MatchPlayer> get teamB => _confirmedOn('B');

  List<MatchPlayer> get confirmedPlayers =>
      players.where((player) => player.isConfirmed).toList(growable: false);

  /// True once the organizer has marked every confirmed player. Completion is
  /// refused by the database until this holds.
  bool get attendanceMarked =>
      confirmedPlayers.every((player) => player.attended != null);

  /// Promotion order: first joined, first promoted.
  List<MatchPlayer> get waitlist =>
      players.where((player) => player.isWaitlisted).toList(growable: false);

  List<MatchPlayer> _confirmedOn(String side) => players
      .where((player) => player.isConfirmed && player.team == side)
      .toList(growable: false);

  MatchPlayer? get me {
    for (final player in players) {
      if (player.userId == currentUserId) return player;
    }
    return null;
  }

  String? get myStatus => me?.status;
  bool get amConfirmed => myStatus == 'confirmed';
  bool get amWaitlisted => myStatus == 'waitlisted';

  bool get isOrganizer =>
      currentUserId != null && currentUserId == match.organizerId;

  /// Same rules join_match() applies: the match must still be open.
  bool get isOpen =>
      match.status == 'scheduled' && match.startsAt.isAfter(DateTime.now());

  /// True when giving up this spot falls inside the three-hour window the
  /// reliability rule penalises. Waiting-list places are never penalised, and
  /// the database counts the same window from left_at.
  bool get isLateCancel => amConfirmed && isLateCancelWindow(match.startsAt);

  bool get canJoin => isOpen && !amConfirmed && !amWaitlisted;
}
