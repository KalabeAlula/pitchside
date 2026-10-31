import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchside/core/theme/app_theme.dart';
import 'package:pitchside/models/match_detail.dart';
import 'package:pitchside/models/match_model.dart';
import 'package:pitchside/models/past_match.dart';
import 'package:pitchside/models/pitch.dart';
import 'package:pitchside/models/pitch_review.dart';
import 'package:pitchside/models/pitch_slot.dart';
import 'package:pitchside/models/player_standing.dart';
import 'package:pitchside/models/sub_city.dart';
import 'package:pitchside/providers/match_feed_provider.dart';
import 'package:pitchside/providers/service_provider.dart';
import 'package:pitchside/screens/match_feed_screen.dart';
import 'package:pitchside/screens/my_standing_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_pitchside_service.dart';

MatchOverview buildMatch({
  required String id,
  required String pitchName,
  String subCityId = 'bole',
  String subCityName = 'Bole',
  int spotsLeft = 3,
  double pricePerPlayer = 150,
}) {
  return MatchOverview(
    id: id,
    pitchId: 'pitch-$id',
    pitchName: pitchName,
    subCityId: subCityId,
    subCityName: subCityName,
    latitude: 9.0,
    longitude: 38.75,
    organizerId: 'organizer-1',
    organizerName: 'Abebe',
    teamSize: 5,
    maxPlayers: 10,
    currentPlayers: 10 - spotsLeft,
    spotsLeft: spotsLeft,
    startsAt: DateTime.utc(2026, 11, 2, 15, 30),
    endsAt: DateTime.utc(2026, 11, 2, 16, 30),
    pricePerPlayer: pricePerPlayer,
    status: 'scheduled',
  );
}

class FeedFakeService extends FakePitchsideService {
  FeedFakeService({
    required this.subCities,
    required this.matches,
    this.standing = const PlayerStanding(
      score: 100,
      suspendedUntil: null,
      matchesPlayed: 0,
      noShows: 0,
    ),
  });

  final List<SubCity> subCities;
  final List<MatchOverview> matches;
  final PlayerStanding standing;
  final joinedMatches = <String>[];

  @override
  Future<PlayerStanding> getMyStanding() async => standing;

  @override
  Future<List<PastMatch>> getMyPastMatches() async => const [];

  @override
  Future<List<SubCity>> getSubCities() async => subCities;

  @override
  Future<List<MatchOverview>> getMatches({String? subCityId}) async {
    return matches
        .where((m) => subCityId == null || m.subCityId == subCityId)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> joinMatch(String matchId) async {
    joinedMatches.add(matchId);
    return {'match_id': matchId, 'member_status': 'confirmed'};
  }

  @override
  Future<MatchDetail> getMatchDetail(String matchId) async {
    final match = matches.firstWhere((m) => m.id == matchId);
    return MatchDetail(
      match: match,
      players: [
        MatchPlayer(
          userId: match.organizerId,
          fullName: match.organizerName,
          team: 'A',
          status: 'confirmed',
          joinedAt: DateTime.utc(2026, 10, 28),
        ),
      ],
      currentUserId: 'someone-else',
    );
  }

  @override
  Future<bool> cancelMatch(String matchId) async => true;

  @override
  Future<List<Pitch>> getPitches({String? subCityId}) async => const [
    Pitch(
      id: 'pitch-1',
      name: '22 Golagul',
      subCityId: 'bole',
      woreda: 'Woreda 04',
      surface: 'artificial_grass',
      pricePerHour: 500,
      isActive: true,
    ),
  ];

  @override
  Future<List<PitchSlot>> getPitchSlots({
    required String pitchId,
    required DateTime day,
  }) async => const [];

  @override
  Future<List<Pitch>> getPitchCards({
    String? subCityId,
    String query = '',
  }) async => getPitches(subCityId: subCityId);

  @override
  Future<List<PitchReview>> getPitchReviews(String pitchId) async => const [];

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
  Future<void> leaveMatch(String matchId) => throw UnimplementedError();

  @override
  Future<void> shuffleTeams(String matchId) => throw UnimplementedError();
}

Future<FeedFakeService> pumpFeed(WidgetTester tester) async {
  final service = FeedFakeService(
    subCities: const [
      SubCity(id: 'bole', nameEn: 'Bole', nameAm: 'ቦሌ'),
      SubCity(id: 'kirkos', nameEn: 'Kirkos', nameAm: 'ቂርቆስ'),
    ],
    matches: [
      buildMatch(id: 'm1', pitchName: 'Sarbet Turf House'),
      buildMatch(
        id: 'm2',
        pitchName: 'Kazanchis Turf',
        subCityId: 'kirkos',
        subCityName: 'Kirkos',
        spotsLeft: 0,
        pricePerPlayer: 200,
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [pitchsideServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const MatchFeedScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  group('MatchOverview', () {
    test('isFull and formatLabel derive from capacity and team size', () {
      expect(buildMatch(id: 'm', pitchName: 'P', spotsLeft: 3).isFull, isFalse);
      expect(buildMatch(id: 'm', pitchName: 'P', spotsLeft: 0).isFull, isTrue);
      expect(buildMatch(id: 'm', pitchName: 'P').formatLabel, '5v5');
    });

    test('parses the match_overview row shape', () {
      final match = MatchOverview.fromJson({
        'id': 'm1',
        'pitch_id': 'p1',
        'pitch_name': 'Sarbet Turf House',
        'sub_city_id': 'bole',
        'sub_city_name': 'Bole',
        'latitude': 8.9975,
        'longitude': 38.736,
        'organizer_id': 'o1',
        'organizer_name': 'Abebe',
        'team_size': 5,
        'max_players': 10,
        'current_players': 7,
        'spots_left': 3,
        'starts_at': '2026-11-02T15:30:00+00:00',
        'ends_at': '2026-11-02T16:30:00+00:00',
        'price_per_player': 150.0,
        'status': 'scheduled',
        'notes': null,
      });

      expect(match.spotsLeft, 3);
      expect(match.isFull, isFalse);
      expect(match.pricePerPlayer, 150.0);
    });
  });

  group('MatchFeedScreen', () {
    testWidgets('renders sub-city filters and match cards', (tester) async {
      await pumpFeed(tester);

      expect(find.text('All of Addis'), findsOneWidget);
      expect(find.text('Bole'), findsOneWidget);
      expect(find.text('Kirkos'), findsOneWidget);
      expect(find.text('Sarbet Turf House'), findsOneWidget);
      expect(find.text('Kazanchis Turf'), findsOneWidget);
      expect(find.text('3 spots left!'), findsOneWidget);
      expect(find.text('150 ETB'), findsOneWidget);
      expect(find.text('200 ETB'), findsOneWidget);
    });

    testWidgets('shows the kickoff in Addis time', (tester) async {
      await pumpFeed(tester);

      // 15:30 UTC on 2 Nov 2026 is 18:30 EAT, whatever the device clock says.
      expect(find.textContaining('Mon, 2 Nov · 18:30'), findsNWidgets(2));
    });

    testWidgets('tapping a card opens its match page', (tester) async {
      await pumpFeed(tester);

      await tester.tap(find.text('Sarbet Turf House'));
      await tester.pumpAndSettle();

      expect(find.text('Match details'), findsOneWidget);
      expect(find.text('Team A'), findsOneWidget);
      expect(find.text('Abebe'), findsOneWidget);
    });

    testWidgets('the shield opens my standing', (tester) async {
      await pumpFeed(tester);

      await tester.tap(find.byTooltip('My standing'));
      await tester.pumpAndSettle();

      expect(find.byType(MyStandingScreen), findsOneWidget);
      expect(find.text('Reliability score'), findsOneWidget);
    });

    testWidgets('filtering by sub-city narrows the feed', (tester) async {
      await pumpFeed(tester);

      await tester.tap(find.text('Kirkos'));
      await tester.pumpAndSettle();

      expect(find.text('Kazanchis Turf'), findsOneWidget);
      expect(find.text('Sarbet Turf House'), findsNothing);

      await tester.tap(find.text('All of Addis'));
      await tester.pumpAndSettle();
      expect(find.text('Sarbet Turf House'), findsOneWidget);
    });

    testWidgets('join opens the confirmation sheet and confirms', (
      tester,
    ) async {
      final service = await pumpFeed(tester);

      await tester.tap(find.text('Join match'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm your spot'), findsOneWidget);
      expect(find.text('3 of 10 spots still open'), findsOneWidget);
      expect(service.joinedMatches, isEmpty);

      await tester.tap(find.text('Confirm spot'));
      await tester.pumpAndSettle();

      expect(service.joinedMatches, ['m1']);
      expect(find.text('Confirm your spot'), findsNothing);
      expect(
        find.text('Spot confirmed. See you on the pitch!'),
        findsOneWidget,
      );
    });

    testWidgets('dismissing the confirmation sheet joins nothing', (
      tester,
    ) async {
      final service = await pumpFeed(tester);

      await tester.tap(find.text('Join match'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm your spot'), findsNothing);
      expect(service.joinedMatches, isEmpty);
    });

    testWidgets('full match never opens the confirmation sheet', (
      tester,
    ) async {
      final service = await pumpFeed(tester);

      await tester.tap(find.text('Full').last);
      await tester.pumpAndSettle();

      expect(find.text('Confirm your spot'), findsNothing);
      expect(
        find.text('Kazanchis Turf is full — open it to join the waiting list.'),
        findsOneWidget,
      );
      expect(service.joinedMatches, isEmpty);
    });

    testWidgets('renders in dark mode', (tester) async {
      final service = FeedFakeService(
        subCities: const [],
        matches: [buildMatch(id: 'm1', pitchName: 'Sarbet Turf House')],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [pitchsideServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            home: const MatchFeedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Sarbet Turf House'));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(find.text('3 spots left!'), findsOneWidget);
    });
  });

  group('joinErrorMessage', () {
    test('explains a reliability suspension', () {
      expect(
        joinErrorMessage(PostgrestException(message: 'blocked', code: '45022')),
        'Your reliability score is too low to join public games yet.',
      );
    });
  });
}
