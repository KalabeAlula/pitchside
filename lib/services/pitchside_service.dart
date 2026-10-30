import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pitch.dart';
import '../models/pitch_review.dart';
import '../models/pitch_slot.dart';
import '../models/match_detail.dart';
import '../models/match_model.dart';
import '../models/sub_city.dart';

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
        .select('id, rating, comment, created_at, profiles(full_name)')
        .eq('pitch_id', pitchId)
        .order('created_at', ascending: false)
        .limit(20);
    return (response as List)
        .map((json) => PitchReview.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Upcoming scheduled matches, optionally narrowed to one sub-city.
  /// Filtering happens in Postgres, not on the device.
  Future<List<MatchOverview>> getMatches({String? subCityId}) async {
    var query = _client
        .from('match_overview')
        .select()
        .eq('status', 'scheduled')
        .gt('starts_at', DateTime.now().toUtc().toIso8601String());
    if (subCityId != null) {
      query = query.eq('sub_city_id', subCityId);
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
        .select('user_id, team, member_status, joined_at, profiles(full_name)')
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

  /// Create a new match (organizer is automatically registered on Team A)
  Future<Map<String, dynamic>> createMatch({
    required String pitchId,
    required int teamSize,
    required DateTime startsAt,
    int durationMinutes = 60,
    double pricePerPlayer = 0.0,
    String? notes,
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
      },
    );
    return Map<String, dynamic>.from(response as Map);
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
}
