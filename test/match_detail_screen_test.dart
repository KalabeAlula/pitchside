import 'package:flutter/material.dart';
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
import 'package:pitchside/screens/match_detail_screen.dart';
import 'package:pitchside/services/pitchside_service.dart';

MatchOverview buildMatch({
  String status = 'scheduled',
  int teamSize = 5,
  int spotsLeft = 8,
}) {
  final startsAt = DateTime.now().add(const Duration(days: 2));
  return MatchOverview(
    id: 'm1',
    pitchId: 'p1',
    pitchName: 'Sarbet Turf House',
    subCityId: 'bole',
    subCityName: 'Bole',
    latitude: 8.99,
    longitude: 38.74,
    organizerId: 'organizer-1',
    organizerName: 'Abebe Bekele',
    teamSize: teamSize,
    maxPlayers: teamSize * 2,
    currentPlayers: teamSize * 2 - spotsLeft,
    spotsLeft: spotsLeft,
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(minutes: 120)),
    pricePerPlayer: 150,
    status: status,
    notes: 'Bring a light and dark shirt',
  );
}

MatchDetail buildDetail({
  String currentUserId = 'me',
  String? myStatus,
  String status = 'scheduled',
  int spotsLeft = 8,
}) {
  return MatchDetail(
    match: buildMatch(status: status, spotsLeft: spotsLeft),
    players: [
      MatchPlayer(
        userId: 'organizer-1',
        fullName: 'Abebe Bekele',
        team: 'A',
        status: 'confirmed',
        joinedAt: DateTime(2026, 10, 28),
      ),
      MatchPlayer(
        userId: 'p2',
        fullName: 'Dawit Hailu',
        team: 'B',
        status: 'confirmed',
        joinedAt: DateTime(2026, 10, 29),
      ),
      MatchPlayer(
        userId: 'w1',
        fullName: 'Selam Tadesse',
        team: null,
        status: 'waitlisted',
        joinedAt: DateTime(2026, 10, 30),
      ),
      if (myStatus != null)
        MatchPlayer(
          userId: 'me',
          fullName: 'Kaleab Girma',
          team: myStatus == 'confirmed' ? 'A' : null,
          status: myStatus,
          joinedAt: DateTime(2026, 10, 30, 12),
        ),
    ],
    currentUserId: currentUserId,
  );
}

class FakeMatchDetailService implements PitchsideService {
  FakeMatchDetailService(this.detail);

  MatchDetail detail;
  String joinStatus = 'confirmed';
  final left = <String>[];
  final shuffled = <String>[];
  final cancelled = <String>[];
  final joined = <String>[];

  @override
  Future<MatchDetail> getMatchDetail(String matchId) async => detail;

  @override
  Future<Map<String, dynamic>> joinMatch(String matchId) async {
    joined.add(matchId);
    return {'match_id': matchId, 'member_status': joinStatus};
  }

  @override
  Future<void> leaveMatch(String matchId) async => left.add(matchId);

  @override
  Future<void> shuffleTeams(String matchId) async => shuffled.add(matchId);

  @override
  Future<bool> cancelMatch(String matchId) async {
    cancelled.add(matchId);
    return true;
  }

  @override
  Future<List<SubCity>> getSubCities() async => const [];

  @override
  Future<List<MatchOverview>> getMatches({String? subCityId}) async => const [];

  @override
  Future<List<Pitch>> getPitches({String? subCityId}) async => const [];

  @override
  Future<List<Pitch>> getPitchCards({
    String? subCityId,
    String query = '',
  }) async => const [];

  @override
  Future<List<PitchReview>> getPitchReviews(String pitchId) async => const [];

  @override
  Future<List<PitchSlot>> getPitchSlots({
    required String pitchId,
    required DateTime day,
  }) async => const [];

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
  }) => throw UnimplementedError();
}

Future<FakeMatchDetailService> pumpDetail(
  WidgetTester tester,
  MatchDetail detail,
) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = FakeMatchDetailService(detail);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pitchsideServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MatchDetailScreen(matchId: 'm1', initialMatch: detail.match),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  group('MatchPlayer', () {
    test('initials come from the first and last word', () {
      MatchPlayer player(String name) => MatchPlayer(
        userId: 'x',
        fullName: name,
        team: 'A',
        status: 'confirmed',
        joinedAt: DateTime(2026, 10, 28),
      );

      expect(player('Abebe Bekele').initials, 'AB');
      expect(player('Selam').initials, 'S');
      expect(player('  dawit  hailu  ').initials, 'DH');
    });
  });

  group('MatchDetailScreen', () {
    testWidgets('shows teams, the waiting list and organizer controls', (
      tester,
    ) async {
      await pumpDetail(tester, buildDetail(currentUserId: 'organizer-1'));

      expect(find.text('Sarbet Turf House'), findsOneWidget);
      expect(find.text('8 spots left!'), findsOneWidget);
      expect(find.text('Bring a light and dark shirt'), findsOneWidget);
      expect(find.text('Team A'), findsOneWidget);
      expect(find.text('Team B'), findsOneWidget);
      expect(find.text('Abebe Bekele'), findsOneWidget);
      expect(find.text('Dawit Hailu'), findsOneWidget);
      expect(find.text('Waiting list'), findsOneWidget);
      expect(find.text('Selam Tadesse'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('Cancel match'), findsOneWidget);
      expect(find.text('Join match'), findsNothing);
    });

    testWidgets('a player joins a full match through the waiting list', (
      tester,
    ) async {
      final service = await pumpDetail(tester, buildDetail(spotsLeft: 0));
      service.joinStatus = 'waitlisted';

      expect(find.text('Join waiting list'), findsOneWidget);
      await tester.tap(find.text('Join waiting list'));
      await tester.pumpAndSettle();

      expect(find.text('Join the waiting list?'), findsOneWidget);
      await tester.tap(find.text('Join list'));
      await tester.pumpAndSettle();

      expect(service.joined, ['m1']);
      expect(find.text("You're on the waiting list."), findsOneWidget);
    });

    testWidgets('joins an open match through the confirmation sheet', (
      tester,
    ) async {
      final service = await pumpDetail(tester, buildDetail());

      await tester.tap(find.text('Join match'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm your spot'), findsOneWidget);
      await tester.tap(find.text('Confirm spot'));
      await tester.pumpAndSettle();

      expect(service.joined, ['m1']);
      expect(
        find.text('Spot confirmed. See you on the pitch!'),
        findsOneWidget,
      );
    });

    testWidgets('a confirmed player can leave after confirming', (
      tester,
    ) async {
      final service = await pumpDetail(
        tester,
        buildDetail(myStatus: 'confirmed'),
      );

      await tester.tap(find.text('Leave match'));
      await tester.pumpAndSettle();

      expect(find.text('Leave this match?'), findsOneWidget);
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(service.left, ['m1']);
      expect(find.text('You left the match.'), findsOneWidget);
    });

    testWidgets('a waitlisted player leaves the waiting list', (tester) async {
      await pumpDetail(tester, buildDetail(myStatus: 'waitlisted'));

      expect(find.text('Leave waiting list'), findsOneWidget);
      expect(find.text('you'), findsOneWidget);
    });

    testWidgets('the organizer shuffles teams', (tester) async {
      final service = await pumpDetail(
        tester,
        buildDetail(currentUserId: 'organizer-1'),
      );

      await tester.tap(find.text('Shuffle'));
      await tester.pumpAndSettle();

      expect(service.shuffled, ['m1']);
      expect(find.text('Teams shuffled.'), findsOneWidget);
    });

    testWidgets('the organizer cancels the match after confirming', (
      tester,
    ) async {
      final service = await pumpDetail(
        tester,
        buildDetail(currentUserId: 'organizer-1'),
      );

      await tester.tap(find.text('Cancel match'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel it'));
      await tester.pumpAndSettle();

      expect(service.cancelled, ['m1']);
      expect(find.text('Match cancelled.'), findsOneWidget);
    });

    testWidgets('a cancelled match offers no actions', (tester) async {
      await pumpDetail(
        tester,
        buildDetail(currentUserId: 'organizer-1', status: 'cancelled'),
      );

      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('This match was cancelled.'), findsOneWidget);
      expect(find.text('Cancel match'), findsNothing);
      expect(find.text('Shuffle'), findsNothing);
      expect(find.text('Join match'), findsNothing);
    });
  });
}
