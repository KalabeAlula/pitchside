import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match_model.dart';
import 'service_provider.dart';
import 'sub_cities_provider.dart';

/// Upcoming scheduled matches, re-fetched whenever the sub-city filter changes.
final matchFeedProvider = FutureProvider<List<MatchOverview>>((ref) {
  final subCityId = ref.watch(selectedSubCityProvider);
  return ref.watch(pitchsideServiceProvider).getMatches(subCityId: subCityId);
});

final joinMatchControllerProvider =
    AsyncNotifierProvider<JoinMatchController, void>(JoinMatchController.new);

class JoinMatchController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns the status the server assigned: 'confirmed', or 'waitlisted' when
  /// the roster filled up first. Throws on failure so the caller can show why.
  Future<String> join(String matchId) async {
    state = const AsyncLoading();
    try {
      final row = await ref.read(pitchsideServiceProvider).joinMatch(matchId);
      state = const AsyncData(null);
      ref.invalidate(matchFeedProvider);
      return row['member_status'] as String? ?? 'confirmed';
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

/// Maps the database error codes raised by join_match() to player-facing text.
String joinErrorMessage(Object error) {
  if (error is PostgrestException) {
    return switch (error.code) {
      '45001' => 'That match just filled up. Try another game.',
      '45002' => 'This match is no longer open for joining.',
      '45006' => 'You are already on the roster for this match.',
      '45201' => 'This is a club game — only that club\'s members can join.',
      '45202' => 'The other club has not accepted the challenge yet.',
      '42501' => 'Sign in to join a match.',
      _ => 'Could not join the match. Please try again.',
    };
  }
  return 'No connection. Check your internet and try again.';
}
