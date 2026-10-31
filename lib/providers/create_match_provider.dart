import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pitch.dart';
import 'match_feed_provider.dart';
import 'organizations_provider.dart';
import 'service_provider.dart';

final pitchesProvider = FutureProvider<List<Pitch>>((ref) {
  return ref.watch(pitchsideServiceProvider).getPitches();
});

final createMatchControllerProvider =
    AsyncNotifierProvider<CreateMatchController, void>(
      CreateMatchController.new,
    );

class CreateMatchController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create({
    required String pitchId,
    required int teamSize,
    required DateTime startsAt,
    required int durationMinutes,
    required double pricePerPlayer,
    String? notes,
    String? organizationId,
    String? opponentOrganizationId,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(pitchsideServiceProvider)
          .createMatch(
            pitchId: pitchId,
            teamSize: teamSize,
            startsAt: startsAt,
            durationMinutes: durationMinutes,
            pricePerPlayer: pricePerPlayer,
            notes: notes,
            organizationId: organizationId,
            opponentOrganizationId: opponentOrganizationId,
          );
      state = const AsyncData(null);
      ref.invalidate(matchFeedProvider);
      if (organizationId != null) {
        ref.invalidate(orgMatchesProvider);
      }
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

String createMatchErrorMessage(Object error) {
  if (error is PostgrestException) {
    return switch (error.code) {
      '45000' => 'Choose an active pitch.',
      '45008' => 'Choose a kickoff time in the future.',
      '45014' => 'Team size must be between 5v5 and 11v11.',
      '45015' => 'Duration must be between 30 and 180 minutes.',
      '45016' => 'That slot was just booked. Pick another one.',
      '45203' => 'Only club owners and managers can host a club match.',
      '45207' => 'Choose another club as the opponent.',
      '42501' => 'Sign in to create a match.',
      _ => 'Could not create the match. Please try again.',
    };
  }
  return 'No connection. Check your internet and try again.';
}
