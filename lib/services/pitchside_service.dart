import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pitch.dart';
import '../models/pitch_review.dart';
import '../models/pitch_slot.dart';
import '../models/match_detail.dart';
import '../models/match_model.dart';
import '../models/organization.dart';
import '../models/past_match.dart';
import '../models/player_standing.dart';
import '../models/sub_city.dart';
import '../models/upcoming_match.dart';

class PitchsideService {
  final SupabaseClient _client;

  PitchsideService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Fetch all active sub-cities of Addis Ababa
  Future<List<SubCity>> getSubCities() async {
    final response = await _client
        .from('sub_cities')
        .select()
        .order('name_en', ascending: true);
    return (response as List).map((json) => SubCity.fromJson(json)).toList();
  }

  /// Fetch all active pitches
  Future<List<Pitch>> getPitches({String? subCityId}) async {
    var query = _client.from('pitches').select().eq('is_active', true);
    if (subCityId != null) {
      query = query.eq('sub_city_id', subCityId);
    }
    final response = await query.order('name', ascending: true);
    return (response as List).map((json) => Pitch.fromJson(json)).toList();
  }

  /// Fetch pitches near coordinates in Addis Ababa
  Future<List<Pitch>> getNearbyPitches({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) async {
    final response = await _client.rpc(
      'nearby_pitches',
      params: {
        'p_lat': latitude,
        'p_lng': longitude,
        'p_radius_m': radiusMeters,
      },
    );
    return (response as List).map((json) => Pitch.fromJson(json)).toList();
  }

  /// Field directory: active pitches with their aggregate rating folded in.
  /// Filtering runs in Postgres so the device never pages a long list.
  Future<List<Pitch>> getPitchCards({
    String? subCityId,
    String query = '',
  }) async {
    var request = _client.from('pitch_cards').select();
    if (subCityId != null) {
      request = request.eq('sub_city_id', subCityId);
    }
    final term = query.trim().replaceAll(RegExp(r'[,()]'), ' ');
    if (term.isNotEmpty) {
      request = request.or(
        'name.ilike.%$term%,address.ilike.%$term%,woreda.ilike.%$term%',
      );
    }
    final response = await request.order('name', ascending: true);
    return (response as List).map((json) => Pitch.fromJson(json)).toList();
  }

  /// Bookable blocks for one field on one Addis calendar day.
  Future<List<PitchSlot>> getPitchSlots({
    required String pitchId,
    required DateTime day,
  }) async {
    final response = await _client.rpc(
      'pitch_slots',
      params: {
        'p_pitch_id': pitchId,
        'p_day': DateFormat('yyyy-MM-dd').format(day),
      },
    );
    return (response as List)
        .map((json) => PitchSlot.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<PitchReview>> getPitchReviews(String pitchId) async {
    final response = await _client
        .from('pitch_reviews')
        .select(
          'id, reviewer_id, rating, comment, created_at, '
          'profiles(full_name)',
        )
        .eq('pitch_id', pitchId)
        .order('created_at', ascending: false)
        .limit(20);
    return (response as List)
        .map((json) => PitchReview.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Whether the caller may review this field and what they already said.
  /// The database decides with the same rule that guards the write.
  Future<PitchReviewState> getPitchReviewState(String pitchId) async {
    final response = await _client.rpc(
      'pitch_review_state',
      params: {'p_pitch_id': pitchId},
    );
    final row = (response as List).first as Map<String, dynamic>;
    return PitchReviewState.fromJson(row);
  }

  /// Rate a field the caller played. Repeat calls edit the existing review.
  Future<void> submitPitchReview({
    required String pitchId,
    required int rating,
    String? comment,
  }) async {
    await _client.rpc(
      'submit_pitch_review',
      params: {'p_pitch_id': pitchId, 'p_rating': rating, 'p_comment': comment},
    );
  }

  /// Upcoming scheduled matches, optionally narrowed to one sub-city.
  /// Filtering happens in Postgres, not on the device. Club games are not
  /// public pickups, so the feed asks for the public audience only.
  Future<List<MatchOverview>> getMatches({String? subCityId}) async {
    var query = _client
        .from('match_overview')
        .select()
        .eq('status', 'scheduled')
        .eq('audience', 'public')
        .gt('starts_at', DateTime.now().toUtc().toIso8601String());
    if (subCityId != null) {
      query = query.eq('sub_city_id', subCityId);
    }
    final response = await query.order('starts_at', ascending: true);
    return (response as List)
        .map((json) => MatchOverview.fromJson(json))
        .toList();
  }

  /// Upcoming club matches the signed-in player can see: internal games of
  /// their clubs and challenges involving them. RLS narrows the rows; the
  /// audience filter keeps public pickups out of the club view.
  Future<List<MatchOverview>> getOrgMatches({String? organizationId}) async {
    var query = _client
        .from('match_overview')
        .select()
        .eq('status', 'scheduled')
        .neq('audience', 'public')
        .gt('starts_at', DateTime.now().toUtc().toIso8601String());
    if (organizationId != null) {
      query = query.or(
        'organization_id.eq.$organizationId,'
        'opponent_organization_id.eq.$organizationId',
      );
    }
    final response = await query.order('starts_at', ascending: true);
    return (response as List)
        .map((json) => MatchOverview.fromJson(json))
        .toList();
  }

  /// One match with its roster. The caller's id rides along so the screen can
  /// tell an organizer from a player without a second session lookup.
  Future<MatchDetail> getMatchDetail(String matchId) async {
    final matchRow = await _client
        .from('match_overview')
        .select()
        .eq('id', matchId)
        .single();
    final roster = await _client
        .from('match_players')
        .select(
          'user_id, team, member_status, joined_at, attended, '
          'profiles(full_name)',
        )
        .eq('match_id', matchId)
        .order('joined_at', ascending: true);
    return MatchDetail(
      match: MatchOverview.fromJson(Map<String, dynamic>.from(matchRow)),
      players: (roster as List)
          .map(
            (json) =>
                MatchPlayer.fromJson(Map<String, dynamic>.from(json as Map)),
          )
          .toList(),
      currentUserId: _client.auth.currentUser?.id,
    );
  }

  /// Organizer-only. Returns false when RLS left the row untouched, which is
  /// how a non-organizer's attempt comes back. Cancelling frees the field block
  /// because pitch_slots() only counts scheduled matches.
  Future<bool> cancelMatch(String matchId) async {
    final rows = await _client
        .from('matches')
        .update({'status': 'cancelled'})
        .eq('id', matchId)
        .select('id');
    return (rows as List).isNotEmpty;
  }

  /// Organizer's roll call, allowed only after kickoff. Everyone passed in
  /// [presentUserIds] is recorded as attended; the rest of the confirmed
  /// roster becomes a no-show. Can be called again to correct a mark.
  Future<({int present, int absent})> markAttendance(
    String matchId,
    List<String> presentUserIds,
  ) async {
    final response = await _client.rpc(
      'mark_attendance',
      params: {'p_match_id': matchId, 'p_present_user_ids': presentUserIds},
    );
    final row = (response as List).first as Map<String, dynamic>;
    return (
      present: (row['present_count'] as num).toInt(),
      absent: (row['absent_count'] as num).toInt(),
    );
  }

  /// Organizer-only. Closes the match after the roll call is complete; the
  /// database refuses while any confirmed player is still unmarked.
  Future<void> completeMatch(String matchId) async {
    await _client.rpc('complete_match', params: {'p_match_id': matchId});
  }

  /// The caller's own reliability record. The score columns are trigger-owned,
  /// so this is read-only; RLS exposes only the signed-in player's row.
  Future<PlayerStanding> getMyStanding() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in to see your standing.');
    }
    final row = await _client
        .from('profiles')
        .select('reliability_score, suspended_until, matches_played, no_shows')
        .eq('id', userId)
        .single();
    return PlayerStanding.fromJson(Map<String, dynamic>.from(row));
  }

  /// Completed matches the caller was confirmed in, newest first. The view
  /// already narrows to the caller, so there is no extra filter to add here.
  Future<List<PastMatch>> getMyPastMatches() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final response = await _client
        .from('my_past_matches')
        .select()
        .order('starts_at', ascending: false)
        .limit(30);
    return (response as List)
        .map(
          (json) => PastMatch.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  /// Scheduled matches the caller is still confirmed in, kickoff first.
  Future<List<UpcomingMatch>> getMyUpcomingMatches() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final response = await _client
        .from('my_upcoming_matches')
        .select()
        .order('starts_at', ascending: true)
        .limit(5);
    return (response as List)
        .map(
          (json) =>
              UpcomingMatch.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  /// Create a new match (organizer is automatically registered on Team A).
  /// Passing a club makes it an internal club game; adding an opponent turns
  /// it into a challenge the other club has to accept.
  Future<Map<String, dynamic>> createMatch({
    required String pitchId,
    required int teamSize,
    required DateTime startsAt,
    int durationMinutes = 60,
    double pricePerPlayer = 0.0,
    String? notes,
    String? organizationId,
    String? opponentOrganizationId,
  }) async {
    final response = await _client.rpc(
      'create_match',
      params: {
        'p_pitch_id': pitchId,
        'p_team_size': teamSize,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_duration_minutes': durationMinutes,
        'p_price_per_player': pricePerPlayer,
        'p_notes': notes,
        'p_organization_id': organizationId,
        'p_opponent_organization_id': opponentOrganizationId,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Clubs the signed-in player belongs to, with their seat in each.
  Future<List<OrganizationMembership>> getMyOrganizations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final response = await _client
        .from('organization_members')
        .select(
          'role, joined_at, '
          'organizations(id, name, about, sub_city_id, created_by, created_at)',
        )
        .eq('user_id', userId)
        .order('joined_at', ascending: false);
    return (response as List)
        .map(
          (json) => OrganizationMembership.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();
  }

  /// Every club on Pitchside — the list a challenge picks an opponent from.
  /// The join code is not part of this row; it lives in a manager-only table.
  Future<List<Organization>> getOrganizations() async {
    final response = await _client
        .from('organizations')
        .select()
        .order('name', ascending: true);
    return (response as List)
        .map(
          (json) =>
              Organization.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  Future<Organization> createOrganization({
    required String name,
    String? about,
    String? subCityId,
  }) async {
    final response = await _client.rpc(
      'create_organization',
      params: {'p_name': name, 'p_about': about, 'p_sub_city_id': subCityId},
    );
    return Organization.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Organization> joinOrganization(String code) async {
    final response = await _client.rpc(
      'join_organization',
      params: {'p_code': code},
    );
    return Organization.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> leaveOrganization(String organizationId) async {
    await _client.rpc(
      'leave_organization',
      params: {'p_org_id': organizationId},
    );
  }

  Future<List<OrganizationMember>> getOrganizationMembers(
    String organizationId,
  ) async {
    final response = await _client
        .from('organization_members')
        .select('user_id, role, joined_at, profiles(full_name)')
        .eq('org_id', organizationId)
        .order('joined_at', ascending: true);
    return (response as List)
        .map(
          (json) => OrganizationMember.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();
  }

  /// Null when the caller is not a manager: RLS hides the row from everyone
  /// else, so the code never reaches a regular member's device.
  Future<String?> getOrganizationJoinCode(String organizationId) async {
    final row = await _client
        .from('organization_join_codes')
        .select('code')
        .eq('org_id', organizationId)
        .maybeSingle();
    return row?['code'] as String?;
  }

  /// Accept or decline a club challenge. Declining cancels the match, which
  /// frees the field block the host booked.
  Future<void> respondToChallenge(
    String matchId, {
    required bool accept,
  }) async {
    await _client.rpc(
      'respond_to_challenge',
      params: {'p_match_id': matchId, 'p_accept': accept},
    );
  }

  /// Join a match (concurrency safe, auto team balance, auto-waitlists if full)
  Future<Map<String, dynamic>> joinMatch(String matchId) async {
    final response = await _client.rpc(
      'join_match',
      params: {'p_match_id': matchId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Leave a match (auto-promotes earliest waitlisted player)
  Future<void> leaveMatch(String matchId) async {
    await _client.rpc('leave_match', params: {'p_match_id': matchId});
  }

  /// Shuffle teams randomly (organizer only)
  Future<void> shuffleTeams(String matchId) async {
    await _client.rpc('shuffle_teams', params: {'p_match_id': matchId});
  }

  /// The signed-in account's role, or null when signed out. Operators are the
  /// accounts allowed to drop exact field pins.
  Future<String?> getMyRole() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    return row?['role'] as String?;
  }

  /// Operator-only. Stores an exact gate pin and marks the field as pinned by
  /// hand; the database re-checks the role and the Addis bounds.
  Future<Pitch> setPitchPin({
    required String pitchId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client.rpc(
      'set_pitch_pin',
      params: {'p_pitch_id': pitchId, 'p_lat': latitude, 'p_lng': longitude},
    );
    return Pitch.fromJson(Map<String, dynamic>.from(response as Map));
  }
}
