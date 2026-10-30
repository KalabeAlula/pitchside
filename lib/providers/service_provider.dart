import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pitchside_service.dart';

/// Single service instance for the whole app. Overridden in tests with a fake.
final pitchsideServiceProvider = Provider<PitchsideService>(
  (ref) => PitchsideService(),
);
