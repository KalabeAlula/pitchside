import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match_detail.dart';
import 'fields_provider.dart';
import 'match_feed_provider.dart';
import 'service_provider.dart';

final matchDetailProvider = FutureProvider.family<MatchDetail, String>((
  ref,
  matchId,
) {
  return ref.watch(pitchsideServiceProvider).getMatchDetail(matchId);
});

/// Raised when the server accepted the request but changed no row, which means
/// RLS filtered it — in practice, the caller is not the organizer.
class MatchActionException implements Exception {
  const MatchActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

final matchActionControllerProvider =
    AsyncNotifierProvider<MatchActionController, void>(
      MatchActionController.new,
    );

class MatchActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> leave(String matchId) => _run(
    matchId,
    () => ref.read(pitchsideServiceProvider).leaveMatch(matchId),
  );

  Future<void> shuffle(String matchId) => _run(
    matchId,
    () => ref.read(pitchsideServiceProvider).shuffleTeams(matchId),
  );

  Future<void> cancel(String matchId) => _run(matchId, () async {
    final cancelled = await ref
        .read(pitchsideServiceProvider)
        .cancelMatch(matchId);
    if (!cancelled) {
      throw const MatchActionException(
        'Only the organizer can cancel this match.',
      );
    }
  });

  /// Every action changes the roster or the match row, and cancelling frees a
  /// field block, so all three views refresh together.
  Future<void> _run(String matchId, Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      ref.invalidate(matchDetailProvider(matchId));
      ref.invalidate(matchFeedProvider);
      ref.invalidate(pitchSlotsProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

/// Maps the database error codes raised by leave_match() / shuffle_teams() to
/// player-facing text.
String matchActionErrorMessage(Object error) {
  if (error is MatchActionException) return error.message;
  if (error is PostgrestException) {
    return switch (error.code) {
      '45001' => 'That match just filled up. Try another game.',
      '45002' => 'This match is no longer open.',
      '45006' => 'You are not on this roster.',
      '45007' => 'The organizer has to cancel the match instead of leaving.',
      '42501' => 'Only the organizer can do that.',
      _ => 'Could not update the match. Please try again.',
    };
  }
  return 'No connection. Check your internet and try again.';
}
