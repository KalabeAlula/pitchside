import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/past_match.dart';
import '../models/player_standing.dart';
import '../models/upcoming_match.dart';
import 'service_provider.dart';

/// The signed-in player's reliability score and suspension. Re-read on every
/// visit because attendance and cancellations change it elsewhere.
final myStandingProvider = FutureProvider<PlayerStanding>(
  (ref) => ref.watch(pitchsideServiceProvider).getMyStanding(),
);

/// Completed games the player was confirmed in. Disposed with the standing
/// screen so a return visit sees freshly completed matches.
final myPastMatchesProvider = FutureProvider.autoDispose<List<PastMatch>>(
  (ref) => ref.watch(pitchsideServiceProvider).getMyPastMatches(),
);

/// Games the player is still signed up for, kickoff first.
final myUpcomingMatchesProvider =
    FutureProvider.autoDispose<List<UpcomingMatch>>(
      (ref) => ref.watch(pitchsideServiceProvider).getMyUpcomingMatches(),
    );
