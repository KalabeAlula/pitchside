import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sub_city.dart';
import 'service_provider.dart';

final subCitiesProvider = FutureProvider<List<SubCity>>(
  (ref) => ref.watch(pitchsideServiceProvider).getSubCities(),
);

/// Null means "all of Addis Ababa".
final selectedSubCityProvider = NotifierProvider<SelectedSubCity, String?>(
  SelectedSubCity.new,
);

class SelectedSubCity extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? subCityId) => state = subCityId;
}
