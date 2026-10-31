import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/player_standing.dart';
import 'service_provider.dart';

/// The signed-in player's reliability score and suspension. Re-read on every
/// visit because attendance and cancellations change it elsewhere.
final myStandingProvider = FutureProvider<PlayerStanding>(
  (ref) => ref.watch(pitchsideServiceProvider).getMyStanding(),
);
