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

import 'support/fake_pitchside_service.dart';

MatchOverview buildMatch({
  String status = 'scheduled',
  int teamSize = 5,
  int spotsLeft = 8,
  DateTime? startsAt,
}) {
  final kickoff = startsAt ?? DateTime.now().add(const Duration(days: 2));
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
    startsAt: kickoff,
    endsAt: kickoff.add(const Duration(minutes: 120)),
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
  DateTime? startsAt,
  bool marked = false,
  Set<String> absent = const {},
}) {
  MatchPlayer player(
    String id,
    String name,
    String? team,
    String memberStatus,
    DateTime joinedAt,
  ) {
    return MatchPlayer(
      userId: id,
      fullName: name,
      team: team,
      status: memberStatus,
      joinedAt: joinedAt,
      attended: marked && memberStatus == 'confirmed'
          ? !absent.contains(id)
          : null,
    );
  }

  return MatchDetail(
    match: buildMatch(status: status, spotsLeft: spotsLeft, startsAt: startsAt),
    players: [
      player(
        'organizer-1',
        'Abebe Bekele',
        'A',
        'confirmed',
        DateTime(2026, 10, 28),
      ),
      player('p2', 'Dawit Hailu', 'B', 'confirmed', DateTime(2026, 10, 29)),
      player('w1', 'Selam Tadesse', null, 'waitlisted', DateTime(2026, 10, 30)),
      if (myStatus != null)
        player(
          'me',
          'Kaleab Girma',
          myStatus == 'confirmed' ? 'A' : null,
          myStatus,
          DateTime(2026, 10, 30, 12),
        ),
    ],
    currentUserId: currentUserId,
  );
}

class FakeMatchDetailService extends FakePitchsideService {
  FakeMatchDetailService(this.detail);

  MatchDetail detail;
  String joinStatus = 'confirmed';
  final left = <String>[];
  final shuffled = <String>[];
  final cancelled = <String>[];
  final joined = <String>[];
  final marked = <List<String>>[];
  final completed = <String>[];
  PitchReviewState reviewState = const PitchReviewState(canReview: false);
  final submittedReviews = <({int rating, String? comment})>[];

  @override
  Future<PitchReviewState> getPitchReviewState(String pitchId) async =>
      reviewState;

  @override
  Future<void> submitPitchReview({
    required String pitchId,
    required int rating,
    String? comment,
  }) async {
    submittedReviews.add((rating: rating, comment: comment));
    reviewState = PitchReviewState(
      canReview: true,
      myRating: rating,
      myComment: comment,
    );
  }

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
  Future<({int present, int absent})> markAttendance(
    String matchId,
    List<String> presentUserIds,
  ) async {
    marked.add(presentUserIds);
    final confirmed = detail.confirmedPlayers;
    final present = confirmed
        .where((player) => presentUserIds.contains(player.userId))
        .length;
    detail = MatchDetail(
      match: detail.match,
      players: [
        for (final player in detail.players)
          MatchPlayer(
            userId: player.userId,
            fullName: player.fullName,
            team: player.team,
            status: player.status,
            joinedAt: player.joinedAt,
            attended: player.isConfirmed
                ? presentUserIds.contains(player.userId)
                : player.attended,
          ),
      ],
      currentUserId: detail.currentUserId,
    );
    return (present: present, absent: confirmed.length - present);
  }

  @override
  Future<void> completeMatch(String matchId) async => completed.add(matchId);

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
    String? organizationId,
    String? opponentOrganizationId,
  }) => throw UnimplementedError();
}

Future<FakeMatchDetailService> pumpDetail(
  WidgetTester tester,
  MatchDetail detail, {
  FakeMatchDetailService? service,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final fake = service ?? FakeMatchDetailService(detail);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pitchsideServiceProvider.overrideWithValue(fake)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MatchDetailScreen(matchId: 'm1', initialMatch: detail.match),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
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

    testWidgets('warns about the penalty before a late confirmed cancel', (
      tester,
    ) async {
      final service = await pumpDetail(
        tester,
        buildDetail(
          myStatus: 'confirmed',
          startsAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );

      await tester.tap(find.text('Leave match'));
      await tester.pumpAndSettle();

      expect(find.text('Leave this late?'), findsOneWidget);
      expect(find.textContaining('less than 3 hours away'), findsOneWidget);
      expect(find.textContaining('25 reliability points'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      expect(find.text('Leave anyway'), findsOneWidget);

      await tester.tap(find.text('Leave anyway'));
      await tester.pumpAndSettle();

      expect(service.left, ['m1']);
      expect(
        find.text(
          'You left the match. 25 points came off your reliability score.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a cancel outside the window stays a plain confirmation', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        buildDetail(
          myStatus: 'confirmed',
          startsAt: DateTime.now().add(const Duration(hours: 4)),
        ),
      );

      await tester.tap(find.text('Leave match'));
      await tester.pumpAndSettle();

      expect(find.text('Leave this match?'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
      expect(find.textContaining('25 reliability points'), findsNothing);
    });

    testWidgets('a waiting-list place is never a late cancel', (tester) async {
      await pumpDetail(
        tester,
        buildDetail(
          myStatus: 'waitlisted',
          startsAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );

      await tester.tap(find.text('Leave waiting list'));
      await tester.pumpAndSettle();

      expect(find.text('Leave this match?'), findsOneWidget);
      expect(find.textContaining('25 reliability points'), findsNothing);
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

    testWidgets('the organizer records the roll call after kickoff', (
      tester,
    ) async {
      final service = await pumpDetail(
        tester,
        buildDetail(
          currentUserId: 'organizer-1',
          startsAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Kickoff has passed.'), findsNothing);

      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();

      expect(find.text('Take attendance'), findsOneWidget);
      expect(find.text('2 of 2 present'), findsOneWidget);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Dawit Hailu'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 present'), findsOneWidget);

      await tester.tap(find.text('Save attendance'));
      await tester.pumpAndSettle();

      expect(service.marked.single, ['organizer-1']);
      expect(
        find.text('Attendance saved — 1 present, 1 no-show.'),
        findsOneWidget,
      );
    });

    testWidgets('completion waits for the roll call', (tester) async {
      final service = await pumpDetail(
        tester,
        buildDetail(
          currentUserId: 'organizer-1',
          startsAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );

      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();

      expect(find.text('Take attendance'), findsOneWidget);
      expect(service.completed, isEmpty);

      await tester.tap(find.text('Save attendance'));
      await tester.pumpAndSettle();
      expect(service.marked.single.length, 2);

      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();
      expect(find.text('Complete this match?'), findsOneWidget);

      await tester.tap(find.text('Complete match'));
      await tester.pumpAndSettle();

      expect(service.completed, ['m1']);
      expect(find.text('Match completed.'), findsOneWidget);
    });

    testWidgets('players get no attendance controls after kickoff', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        buildDetail(
          startsAt: DateTime.now().subtract(const Duration(hours: 1)),
          myStatus: 'confirmed',
        ),
      );

      expect(find.text('Kickoff has passed.'), findsOneWidget);
      expect(find.text('Attendance'), findsNothing);
      expect(find.text('Complete'), findsNothing);
    });

    testWidgets('a completed match summarises the roll call', (tester) async {
      await pumpDetail(
        tester,
        buildDetail(
          currentUserId: 'organizer-1',
          status: 'completed',
          marked: true,
          absent: {'p2'},
        ),
      );

      expect(find.text('Played · 1 present, 1 no-show'), findsOneWidget);
      expect(find.text('Attendance'), findsNothing);
    });

    testWidgets('an attending player can rate the field after completion', (
      tester,
    ) async {
      final detail = buildDetail(
        currentUserId: 'organizer-1',
        status: 'completed',
        marked: true,
      );
      final service = FakeMatchDetailService(detail)
        ..reviewState = const PitchReviewState(canReview: true);
      await pumpDetail(tester, detail, service: service);

      expect(find.text('Rate the field'), findsOneWidget);

      await tester.tap(find.text('Rate the field'));
      await tester.pumpAndSettle();
      expect(find.text('How was the field?'), findsOneWidget);

      await tester.tap(find.byTooltip('5 stars'));
      await tester.pump();
      await tester.tap(find.text('Post review'));
      await tester.pumpAndSettle();

      expect(service.submittedReviews.single.rating, 5);
      expect(find.text('Edit your review'), findsOneWidget);
    });
  });
}
