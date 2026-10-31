import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchside/core/theme/app_theme.dart';
import 'package:pitchside/models/match_detail.dart';
import 'package:pitchside/models/match_model.dart';
import 'package:pitchside/models/pitch.dart';
import 'package:pitchside/models/pitch_review.dart';
import 'package:pitchside/models/pitch_slot.dart';
import 'package:pitchside/models/sub_city.dart';
import 'package:pitchside/providers/service_provider.dart';
import 'package:pitchside/screens/fields_screen.dart';
import 'package:pitchside/screens/pin_picker_screen.dart';
import 'package:pitchside/screens/pitch_detail_screen.dart';

import 'support/fake_pitchside_service.dart';

const _atlas = Pitch(
  id: 'p1',
  name: 'Bole Atlas 5-A-Side',
  subCityId: 'bole',
  address: 'Atlas, behind Atlas Hotel',
  woreda: 'Woreda 03',
  description: 'Five-a-side turf in the middle of Atlas.',
  amenities: ['Shower', 'Parking'],
  houseRules: ['No metal studs on turf'],
  ratingAvg: 4.5,
  reviewCount: 10,
  latitude: 8.999,
  longitude: 38.786,
  pinAccuracy: 'exact',
  surface: 'artificial_grass',
  pricePerHour: 1100,
  hasFloodlights: true,
  isActive: true,
);

const _kazanchis = Pitch(
  id: 'p2',
  name: 'Kazanchis Turf',
  subCityId: 'kirkos',
  address: 'Kazanchis, near ECA',
  woreda: 'Woreda 08',
  latitude: 9.0145,
  longitude: 38.764,
  pinAccuracy: 'exact',
  surface: 'artificial_grass',
  pricePerHour: 950,
  hasFloodlights: true,
  isActive: true,
);

const _noPin = Pitch(
  id: 'p3',
  name: 'Berta Meda',
  subCityId: 'akaky-kaliti',
  address: 'Akaky Kaliti, Woreda 05',
  woreda: 'Woreda 05',
  surface: 'red_ash',
  pricePerHour: 200,
  isActive: true,
);

const _approxPin = Pitch(
  id: 'p4',
  name: 'Bambis Football Meda',
  subCityId: 'kirkos',
  address: 'Kirkos, Woreda 01',
  woreda: 'Woreda 01',
  latitude: 9.00987,
  longitude: 38.77199,
  pinAccuracy: 'approximate',
  surface: 'artificial_grass',
  pricePerHour: 500,
  isActive: true,
);

/// Serves a transparent tile from memory so the pin map renders without the
/// network in widget tests.
class FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

class FakeFieldsService extends FakePitchsideService {
  final requestedQueries = <String>[];
  String? role = 'player';
  ({String pitchId, double latitude, double longitude})? savedPin;

  @override
  Future<String?> getMyRole() async => role;

  @override
  Future<Pitch> setPitchPin({
    required String pitchId,
    required double latitude,
    required double longitude,
  }) async {
    savedPin = (pitchId: pitchId, latitude: latitude, longitude: longitude);
    final source = [
      _atlas,
      _kazanchis,
      _noPin,
      _approxPin,
    ].firstWhere((pitch) => pitch.id == pitchId, orElse: () => _approxPin);
    return Pitch.fromJson({
      'id': source.id,
      'name': source.name,
      'sub_city_id': source.subCityId,
      'address': source.address,
      'woreda': source.woreda,
      'latitude': latitude,
      'longitude': longitude,
      'pin_accuracy': 'exact',
      'surface': source.surface,
      'price_per_hour': source.pricePerHour,
      'is_active': true,
    });
  }

  @override
  Future<List<Pitch>> getPitchCards({
    String? subCityId,
    String query = '',
  }) async {
    requestedQueries.add(query);
    final term = query.trim().toLowerCase();
    return [_atlas, _kazanchis].where((pitch) {
      final matchesCity = subCityId == null || pitch.subCityId == subCityId;
      final matchesQuery =
          term.isEmpty ||
          pitch.name.toLowerCase().contains(term) ||
          (pitch.address ?? '').toLowerCase().contains(term) ||
          (pitch.woreda ?? '').toLowerCase().contains(term);
      return matchesCity && matchesQuery;
    }).toList();
  }

  @override
  Future<List<PitchSlot>> getPitchSlots({
    required String pitchId,
    required DateTime day,
  }) async {
    final open = DateTime(day.year, day.month, day.day, 8);
    return [
      PitchSlot(
        start: open,
        end: open.add(const Duration(hours: 2)),
        isBooked: false,
      ),
      PitchSlot(
        start: open.add(const Duration(hours: 2)),
        end: open.add(const Duration(hours: 4)),
        isBooked: true,
      ),
    ];
  }

  @override
  Future<List<PitchReview>> getPitchReviews(String pitchId) async => [
    PitchReview(
      id: 'r1',
      reviewerName: 'Abebe',
      rating: 5,
      comment: 'Great turf, fast surface.',
      createdAt: DateTime.utc(2026, 10, 20),
    ),
  ];

  @override
  Future<List<Pitch>> getPitches({String? subCityId}) async => const [
    _atlas,
    _kazanchis,
  ];

  @override
  Future<List<SubCity>> getSubCities() async => const [
    SubCity(id: 'bole', nameEn: 'Bole', nameAm: 'ቦሌ'),
    SubCity(id: 'kirkos', nameEn: 'Kirkos', nameAm: 'ቂርቆስ'),
  ];

  @override
  Future<List<MatchOverview>> getMatches({String? subCityId}) async => [];

  @override
  Future<List<Pitch>> getNearbyPitches({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> createMatch({
    required String pitchId,
    required int teamSize,
    required DateTime startsAt,
    int durationMinutes = 60,
    double pricePerPlayer = 0.0,
    String? notes,
    String? organizationId,
    String? opponentOrganizationId,
  }) => throw UnimplementedError();

  @override
  Future<MatchDetail> getMatchDetail(String matchId) =>
      throw UnimplementedError();

  @override
  Future<bool> cancelMatch(String matchId) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> joinMatch(String matchId) =>
      throw UnimplementedError();

  @override
  Future<void> leaveMatch(String matchId) => throw UnimplementedError();

  @override
  Future<void> shuffleTeams(String matchId) => throw UnimplementedError();
}

Future<FakeFieldsService> pumpFields(WidgetTester tester) async {
  // Tall phone viewport so both directory cards are built and tappable.
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = FakeFieldsService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pitchsideServiceProvider.overrideWithValue(service)],
      child: MaterialApp(theme: AppTheme.light(), home: const FieldsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

Future<FakeFieldsService> pumpDetail(
  WidgetTester tester,
  Pitch pitch, {
  String? role = 'player',
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = FakeFieldsService()..role = role;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pitchsideServiceProvider.overrideWithValue(service),
        pinTileProviderProvider.overrideWithValue(FakeTileProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: PitchDetailScreen(pitch: pitch),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  group('Pitch model', () {
    test('parses directory columns and treats a missing rating as new', () {
      final rated = Pitch.fromJson({
        'id': 'p1',
        'name': 'Bole Atlas 5-A-Side',
        'sub_city_id': 'bole',
        'address': 'Atlas',
        'woreda': 'Woreda 03',
        'description': 'Fast turf',
        'image_url': null,
        'amenities': ['Shower', 'Parking'],
        'house_rules': ['No metal studs on turf'],
        'rating_avg': 4.5,
        'review_count': 10,
        'latitude': 8.999,
        'longitude': 38.786,
        'surface': 'artificial_grass',
        'price_per_hour': 1100,
        'has_floodlights': true,
        'is_active': true,
      });

      expect(rated.amenities, ['Shower', 'Parking']);
      expect(rated.ratingAvg, 4.5);
      expect(rated.isUnrated, isFalse);
      expect(rated.surfaceLabel, 'Artificial grass');

      final unrated = Pitch.fromJson({
        'id': 'p2',
        'name': 'Kazanchis Turf',
        'sub_city_id': 'kirkos',
        'surface': 'artificial_grass',
        'price_per_hour': 950,
        'has_floodlights': true,
        'is_active': true,
      });

      expect(unrated.amenities, isEmpty);
      expect(unrated.ratingAvg, isNull);
      expect(unrated.isUnrated, isTrue);
      expect(unrated.latitude, isNull);
      expect(unrated.blockHours, 2);
    });

    test('falls back to the city directory rating and block price', () {
      final listing = Pitch.fromJson({
        'id': 'p3',
        'name': '22 Golagul',
        'sub_city_id': 'bole',
        'woreda': 'Woreda 04',
        'directory_rating': 4.9,
        'directory_review_count': 10,
        'latitude': null,
        'longitude': null,
        'surface': 'red_ash',
        'price_per_hour': 500,
        'booking_block_hours': 2,
        'has_floodlights': null,
        'is_active': true,
      });

      expect(listing.displayRating, 4.9);
      expect(listing.hasPlayerReviews, isFalse);
      expect(listing.isUnrated, isFalse);
      expect(listing.blockPrice, 1000);
      expect(listing.surfaceLabel, 'Red ash');
      expect(listing.hasFloodlights, isNull);
    });

    test('pitches compare equal by id', () {
      final copy = Pitch.fromJson({
        'id': 'p1',
        'name': 'Bole Atlas 5-A-Side',
        'sub_city_id': 'bole',
        'latitude': 8.999,
        'longitude': 38.786,
        'surface': 'artificial_grass',
        'price_per_hour': 1100,
        'has_floodlights': true,
        'is_active': true,
      });

      expect(copy, _atlas);
    });
  });

  group('FieldsScreen', () {
    testWidgets('renders the hero, filters and image-led field cards', (
      tester,
    ) async {
      await pumpFields(tester);

      expect(find.text('Find your field'), findsOneWidget);
      expect(find.text('FOOTBALL FIELDS'), findsOneWidget);
      expect(find.text('2 fields'), findsOneWidget);
      expect(find.text('BOOK SLOT'), findsNWidgets(2));
      expect(find.text('Bole Atlas 5-A-Side'), findsOneWidget);
      expect(find.text('Bole · Woreda 03'), findsOneWidget);
      expect(find.text('1,100'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('(10)'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
    });

    testWidgets('sub-city filter narrows the directory', (tester) async {
      await pumpFields(tester);

      await tester.tap(find.text('All subcities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirkos').last);
      await tester.pumpAndSettle();

      expect(find.text('Kazanchis Turf'), findsOneWidget);
      expect(find.text('Bole Atlas 5-A-Side'), findsNothing);
      expect(find.text('1 field'), findsOneWidget);
    });

    testWidgets('search filters after the debounce', (tester) async {
      await pumpFields(tester);

      await tester.enterText(find.byType(TextField), 'atlas');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Bole Atlas 5-A-Side'), findsOneWidget);
      expect(find.text('Kazanchis Turf'), findsNothing);
    });

    testWidgets('opening a field shows its details and reviews', (
      tester,
    ) async {
      await pumpFields(tester);

      await tester.tap(find.text('Bole Atlas 5-A-Side'));
      await tester.pumpAndSettle();

      expect(find.text('About this field'), findsOneWidget);
      expect(
        find.text('Five-a-side turf in the middle of Atlas.'),
        findsOneWidget,
      );
      expect(find.text('Shower'), findsOneWidget);
      expect(find.text('No metal studs on turf'), findsOneWidget);
      expect(find.text('Abebe'), findsOneWidget);
      expect(find.text('Great turf, fast surface.'), findsOneWidget);
      expect(find.text('Pick a slot'), findsOneWidget);
      expect(find.text('08:00 – 10:00'), findsOneWidget);
      expect(find.text('Booked'), findsOneWidget);
      expect(find.text('Get directions'), findsOneWidget);
      expect(find.textContaining('Approximate pin'), findsNothing);
    });

    testWidgets('a field without a published pin still offers directions', (
      tester,
    ) async {
      await pumpDetail(tester, _noPin);

      expect(find.text('Get directions'), findsOneWidget);
      expect(find.textContaining('Exact pin not published'), findsOneWidget);
      expect(
        find.text(
          'No exact pin yet — Maps searches by the name and address above.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an area pin is labelled approximate', (tester) async {
      await pumpDetail(tester, _approxPin);

      expect(find.text('Get directions'), findsOneWidget);
      expect(find.text('Set exact pin'), findsNothing);
      expect(find.text('Move exact pin'), findsNothing);
      expect(
        find.textContaining('9.0099, 38.7720 · Approximate pin'),
        findsOneWidget,
      );
      expect(
        find.textContaining('it marks the area, not the exact gate'),
        findsOneWidget,
      );
    });

    testWidgets('only an operator sees the pin action', (tester) async {
      await pumpDetail(tester, _noPin, role: 'admin');
      expect(find.text('Set exact pin'), findsOneWidget);

      await pumpDetail(tester, _atlas, role: 'admin');
      expect(find.text('Move exact pin'), findsOneWidget);
      expect(find.text('Set exact pin'), findsNothing);
    });

    testWidgets('an operator drops the exact pin from the map', (tester) async {
      final service = await pumpDetail(tester, _approxPin, role: 'admin');

      await tester.tap(find.text('Set exact pin'));
      await tester.pumpAndSettle();

      expect(find.text('Exact pin'), findsOneWidget);
      expect(find.text('Save exact pin'), findsOneWidget);

      await tester.tap(find.byType(FlutterMap));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save exact pin'));
      await tester.pumpAndSettle();

      final saved = service.savedPin;
      expect(saved, isNotNull);
      expect(saved!.pitchId, 'p4');
      expect(saved.latitude, closeTo(9.00987, 0.01));
      expect(saved.longitude, closeTo(38.77199, 0.01));
      expect(find.text('Exact pin saved for this field.'), findsOneWidget);
      expect(find.text('Move exact pin'), findsOneWidget);
      expect(find.textContaining('Approximate pin'), findsNothing);
    });

    testWidgets('a booked block cannot be selected', (tester) async {
      await pumpFields(tester);

      await tester.tap(find.text('Bole Atlas 5-A-Side'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10:00 – 12:00'));
      await tester.pumpAndSettle();

      expect(find.text('Pick a slot above'), findsOneWidget);
    });

    testWidgets('picking a slot preloads the match form', (tester) async {
      await pumpFields(tester);

      await tester.tap(find.text('Bole Atlas 5-A-Side'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('08:00 – 10:00'));
      await tester.pumpAndSettle();

      expect(find.text('2,200 ETB'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create match · 08:00'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create a match'), findsOneWidget);
      expect(find.text('Bole Atlas 5-A-Side'), findsOneWidget);
      expect(find.text('120 minutes'), findsOneWidget);
      expect(find.textContaining('8:00'), findsWidgets);
      expect(find.textContaining('2-hour block at the field'), findsOneWidget);
      expect(find.text('Price per player (ETB)'), findsOneWidget);
    });
  });
}
