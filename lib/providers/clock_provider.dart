import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of "now" for countdowns. Tests pin it so relative labels stay
/// deterministic; the upcoming card rebuilds on a timer to keep it fresh.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
