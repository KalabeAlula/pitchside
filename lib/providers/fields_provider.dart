import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pitch.dart';
import '../models/pitch_review.dart';
import '../models/pitch_slot.dart';
import 'service_provider.dart';

/// Null means "all sub-cities".
final fieldSubCityProvider = NotifierProvider<FieldSubCity, String?>(
  FieldSubCity.new,
);

class FieldSubCity extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? subCityId) => state = subCityId;
}

final fieldSearchProvider = NotifierProvider<FieldSearch, String>(
  FieldSearch.new,
);

class FieldSearch extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

final fieldsProvider = FutureProvider<List<Pitch>>((ref) {
  final subCityId = ref.watch(fieldSubCityProvider);
  final search = ref.watch(fieldSearchProvider);
  return ref
      .watch(pitchsideServiceProvider)
      .getPitchCards(subCityId: subCityId, query: search);
});

final pitchReviewsProvider = FutureProvider.family<List<PitchReview>, String>((
  ref,
  pitchId,
) {
  return ref.watch(pitchsideServiceProvider).getPitchReviews(pitchId);
});

typedef SlotQuery = ({String pitchId, DateTime day});

/// Keyed by the calendar day at midnight so the same day always hits one cache.
final pitchSlotsProvider = FutureProvider.family<List<PitchSlot>, SlotQuery>((
  ref,
  query,
) {
  return ref
      .watch(pitchsideServiceProvider)
      .getPitchSlots(pitchId: query.pitchId, day: query.day);
});
