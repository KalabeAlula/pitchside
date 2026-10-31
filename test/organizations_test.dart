import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchside/core/theme/app_theme.dart';
import 'package:pitchside/core/time/addis_time.dart';
import 'package:pitchside/models/match_detail.dart';
import 'package:pitchside/models/match_model.dart';
import 'package:pitchside/models/organization.dart';
import 'package:pitchside/models/pitch.dart';
import 'package:pitchside/models/pitch_slot.dart';
import 'package:pitchside/models/sub_city.dart';
import 'package:pitchside/providers/service_provider.dart';
import 'package:pitchside/screens/create_match_screen.dart';
import 'package:pitchside/screens/match_detail_screen.dart';
import 'package:pitchside/screens/orgs_screen.dart';

import 'support/fake_pitchside_service.dart';

const _host = Organization(
  id: 'org-host',
  name: 'Bole Rovers',
  about: 'The Tuesday-night team from the 4th floor',
  subCityId: 'bole',
);

const _away = Organization(id: 'org-away', name: 'Kazanchis FC');

const _pitch = Pitch(
  id: 'pitch-1',
  name: 'Sarbet Turf House',
  subCityId: 'bole',
  latitude: 9.0,
  longitude: 38.75,
  surface: 'artificial_turf',
  pricePerHour: 2000,
  hasFloodlights: true,
  isActive: true,
);

MatchOverview buildChallenge({DateTime? acceptedAt}) {
  final startsAt = DateTime.now().add(const Duration(days: 2));
  return MatchOverview(
    id: 'c1',
    pitchId: _pitch.id,
    pitchName: _pitch.name,
    subCityId: 'bole',
    subCityName: 'Bole',
    latitude: 9.0,
    longitude: 38.75,
    organizerId: 'host-manager',
    organizerName: 'Host Manager',
    teamSize: 5,
    maxPlayers: 10,
    currentPlayers: 1,
    spotsLeft: 9,
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 2)),
    pricePerPlayer: 0,
    status: 'scheduled',
    audience: 'challenge',
    organizationId: _host.id,
    organizationName: _host.name,
    opponentOrganizationId: _away.id,
    opponentOrganizationName: _away.name,
    challengeAcceptedAt: acceptedAt,
  );
}

class FakeOrgService extends FakePitchsideService {
  FakeOrgService({
    this.memberships = const [],
    this.directory = const [],
    this.match,
  });

  List<OrganizationMembership> memberships;
  List<Organization> directory;
  MatchOverview? match;
  String currentUserId = 'host-manager';

  final joinedCodes = <String>[];
  final responded = <({String matchId, bool accept})>[];
  final createdMatches = <Map<String, Object?>>[];
  String? createdName;
  String joinCode = 'ABC123';

  @override
  Future<List<OrganizationMembership>> getMyOrganizations() async =>
      memberships;

  @override
  Future<List<Organization>> getOrganizations() async => directory;

  @override
  Future<List<OrganizationMember>> getOrganizationMembers(
    String organizationId,
  ) async => [
    OrganizationMember(
      userId: 'host-manager',
      fullName: 'Host Manager',
      role: 'owner',
      joinedAt: DateTime.utc(2026, 10, 1),
    ),
  ];

  @override
  Future<String?> getOrganizationJoinCode(String organizationId) async =>
      joinCode;

  @override
  Future<List<MatchOverview>> getOrgMatches({String? organizationId}) async {
    final rows = match == null ? <MatchOverview>[] : [match!];
    return rows
        .where(
          (row) =>
              organizationId == null ||
              row.organizationId == organizationId ||
              row.opponentOrganizationId == organizationId,
        )
        .toList();
  }

  @override
  Future<Organization> createOrganization({
    required String name,
    String? about,
    String? subCityId,
  }) async {
    createdName = name;
    return Organization(id: 'org-new', name: name, about: about);
  }

  @override
  Future<Organization> joinOrganization(String code) async {
    joinedCodes.add(code);
    return Organization(id: 'org-away', name: 'Kazanchis FC');
  }

  @override
  Future<MatchDetail> getMatchDetail(String matchId) async => MatchDetail(
    match: match!,
    players: [
      MatchPlayer(
        userId: 'host-manager',
        fullName: 'Host Manager',
        team: 'A',
        status: 'confirmed',
        joinedAt: DateTime.utc(2026, 10, 28),
      ),
    ],
    currentUserId: currentUserId,
  );

  @override
  Future<void> respondToChallenge(
    String matchId, {
    required bool accept,
  }) async {
    responded.add((matchId: matchId, accept: accept));
  }

  @override
  Future<List<Pitch>> getPitches({String? subCityId}) async => [_pitch];

  @override
  Future<List<Pitch>> getPitchCards({
    String? subCityId,
    String query = '',
  }) async => [_pitch];

  @override
  Future<List<PitchSlot>> getPitchSlots({
    required String pitchId,
    required DateTime day,
  }) async {
    final sixteen = addisInstant(day, hour: 16);
    final eighteen = addisInstant(day, hour: 18);
    return [
      PitchSlot(
        start: sixteen,
        end: sixteen.add(const Duration(hours: 2)),
        isBooked: false,
      ),
      PitchSlot(
        start: eighteen,
        end: eighteen.add(const Duration(hours: 2)),
        isBooked: false,
      ),
    ];
  }

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
  }) async {
    createdMatches.add({
      'pitchId': pitchId,
      'teamSize': teamSize,
      'startsAt': startsAt,
      'organizationId': organizationId,
      'opponentOrganizationId': opponentOrganizationId,
    });
    return {'id': 'match-new'};
  }

  @override
  Future<List<SubCity>> getSubCities() async => const [];
}

Future<void> pumpOrgScreen(WidgetTester tester, FakeOrgService service) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [pitchsideServiceProvider.overrideWithValue(service)],
      child: MaterialApp(theme: AppTheme.light(), home: const OrgsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpHostForm(WidgetTester tester, FakeOrgService service) async {
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [pitchsideServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CreateMatchScreen(organization: _host),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<FakeOrgService> pumpChallenge(
  WidgetTester tester, {
  required MatchOverview match,
  required String currentUserId,
  List<OrganizationMembership> memberships = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = FakeOrgService(memberships: memberships, match: match)
    ..currentUserId = currentUserId;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pitchsideServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MatchDetailScreen(matchId: match.id, initialMatch: match),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  group('Organization models', () {
    test('initials take the first letters of the name', () {
      expect(_host.initials, 'BR');
      expect(const Organization(id: 'o', name: 'Kazanchis').initials, 'K');
    });

    test('only owners and managers can manage the club', () {
      const owner = OrganizationMembership(organization: _host, role: 'owner');
      const manager = OrganizationMembership(
        organization: _host,
        role: 'manager',
      );
      const member = OrganizationMembership(
        organization: _host,
        role: 'member',
      );

      expect(owner.canManage, isTrue);
      expect(manager.canManage, isTrue);
      expect(member.canManage, isFalse);
      expect(member.roleLabel, 'Member');
    });

    test('parses a membership row with its embedded club', () {
      final membership = OrganizationMembership.fromJson({
        'role': 'manager',
        'organizations': {
          'id': 'org-host',
          'name': 'Bole Rovers',
          'about': null,
          'sub_city_id': 'bole',
          'created_by': 'host-manager',
          'created_at': '2026-10-01T08:00:00+00:00',
        },
      });

      expect(membership.organization, _host);
      expect(membership.organization.createdAt, DateTime.utc(2026, 10, 1, 8));
      expect(membership.roleLabel, 'Manager');
    });

    test('a challenge names both clubs and waits for an answer', () {
      final match = MatchOverview.fromJson({
        'id': 'c1',
        'pitch_id': 'pitch-1',
        'pitch_name': 'Sarbet Turf House',
        'sub_city_id': 'bole',
        'sub_city_name': 'Bole',
        'organizer_id': 'host-manager',
        'organizer_name': 'Host Manager',
        'team_size': 5,
        'max_players': 10,
        'current_players': 1,
        'spots_left': 9,
        'starts_at': '2026-11-02T15:30:00+00:00',
        'ends_at': '2026-11-02T17:30:00+00:00',
        'price_per_player': 0,
        'status': 'scheduled',
        'audience': 'challenge',
        'organization_id': 'org-host',
        'organization_name': 'Bole Rovers',
        'opponent_organization_id': 'org-away',
        'opponent_organization_name': 'Kazanchis FC',
        'challenge_accepted_at': null,
      });

      expect(match.isChallenge, isTrue);
      expect(match.challengePending, isTrue);
      expect(match.clubLabel, 'Bole Rovers vs Kazanchis FC');

      final accepted = MatchOverview.fromJson({
        ...{
          'id': 'c1',
          'pitch_id': 'pitch-1',
          'pitch_name': 'Sarbet Turf House',
          'sub_city_id': 'bole',
          'sub_city_name': 'Bole',
          'organizer_id': 'host-manager',
          'organizer_name': 'Host Manager',
          'team_size': 5,
          'max_players': 10,
          'current_players': 1,
          'spots_left': 9,
          'starts_at': '2026-11-02T15:30:00+00:00',
          'ends_at': '2026-11-02T17:30:00+00:00',
          'price_per_player': 0,
          'status': 'scheduled',
          'audience': 'challenge',
          'organization_id': 'org-host',
          'organization_name': 'Bole Rovers',
          'opponent_organization_id': 'org-away',
          'opponent_organization_name': 'Kazanchis FC',
        },
        'challenge_accepted_at': '2026-10-30T09:00:00+00:00',
      });

      expect(accepted.challengePending, isFalse);
      expect(accepted.challengeAcceptedAt, DateTime.utc(2026, 10, 30, 9));
    });

    test('an internal game belongs to one club only', () {
      final match = MatchOverview(
        id: 'i1',
        pitchId: 'pitch-1',
        pitchName: 'Sarbet Turf House',
        subCityId: 'bole',
        subCityName: 'Bole',
        latitude: null,
        longitude: null,
        organizerId: 'host-manager',
        organizerName: 'Host Manager',
        teamSize: 5,
        maxPlayers: 10,
        currentPlayers: 2,
        spotsLeft: 8,
        startsAt: DateTime.utc(2026, 11, 2, 15, 30),
        endsAt: DateTime.utc(2026, 11, 2, 17, 30),
        pricePerPlayer: 0,
        status: 'scheduled',
        audience: 'internal',
        organizationId: 'org-host',
        organizationName: 'Bole Rovers',
      );

      expect(match.isOrgMatch, isTrue);
      expect(match.isInternal, isTrue);
      expect(match.isChallenge, isFalse);
      expect(match.clubLabel, 'Bole Rovers');
    });
  });

  group('OrgsScreen', () {
    testWidgets('an empty club list offers both ways in', (tester) async {
      await pumpOrgScreen(tester, FakeOrgService());

      expect(find.text('No club yet'), findsOneWidget);
      expect(find.text('Create a club'), findsOneWidget);
      expect(find.text('Join with a code'), findsOneWidget);
    });

    testWidgets('lists the clubs with the viewer seat', (tester) async {
      await pumpOrgScreen(
        tester,
        FakeOrgService(
          memberships: const [
            OrganizationMembership(organization: _host, role: 'owner'),
          ],
        ),
      );

      expect(find.text('Bole Rovers'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('No club yet'), findsNothing);
    });

    testWidgets('creating a club returns to the list', (tester) async {
      final service = FakeOrgService();
      await pumpOrgScreen(tester, service);

      await tester.tap(find.text('Create a club'));
      await tester.pumpAndSettle();

      expect(find.text('Create a club'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Club or company name'),
        'Bole Rovers',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create club'));
      await tester.pumpAndSettle();

      expect(service.createdName, 'Bole Rovers');
      expect(
        find.text('Bole Rovers is ready for its first game.'),
        findsOneWidget,
      );
    });

    testWidgets('joining with a code adds the player to the club', (
      tester,
    ) async {
      final service = FakeOrgService();
      await pumpOrgScreen(tester, service);

      await tester.tap(find.byTooltip('Join with a code'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'abc123');
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();

      expect(service.joinedCodes, ['ABC123']);
      expect(find.text('You joined Kazanchis FC.'), findsOneWidget);
    });
  });

  group('Hosting a club match', () {
    testWidgets('a challenge carries the opponent club', (tester) async {
      final service = FakeOrgService(directory: const [_host, _away]);
      await pumpHostForm(tester, service);

      expect(find.text('Host a club match'), findsOneWidget);
      expect(find.text('Bole Rovers'), findsOneWidget);

      await tester.tap(find.text('Vs another club'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Opponent club'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kazanchis FC').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pitch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sarbet Turf House').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('16:00 – 18:00'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create match'));
      await tester.tap(find.text('Create match'));
      await tester.pumpAndSettle();

      final created = service.createdMatches.single;
      expect(created['organizationId'], _host.id);
      expect(created['opponentOrganizationId'], _away.id);
    });

    testWidgets('a game inside the club sends no opponent', (tester) async {
      final service = FakeOrgService(directory: const [_host, _away]);
      await pumpHostForm(tester, service);

      expect(find.text('Within club'), findsOneWidget);
      expect(find.text('Opponent club'), findsNothing);

      await tester.tap(find.text('Pitch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sarbet Turf House').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('16:00 – 18:00'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create match'));
      await tester.tap(find.text('Create match'));
      await tester.pumpAndSettle();

      final created = service.createdMatches.single;
      expect(created['organizationId'], _host.id);
      expect(created['opponentOrganizationId'], isNull);
    });

    testWidgets('the opponent picker never lists the host club', (
      tester,
    ) async {
      await pumpHostForm(
        tester,
        FakeOrgService(directory: const [_host, _away]),
      );

      await tester.tap(find.text('Vs another club'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Opponent club'));
      await tester.pumpAndSettle();

      // Two "Bole Rovers" at most: the banner and nothing in the menu.
      expect(find.text('Bole Rovers'), findsOneWidget);
      expect(find.text('Kazanchis FC'), findsWidgets);
    });
  });

  group('Challenge on the match page', () {
    testWidgets('the challenged club can accept the invite', (tester) async {
      final service = await pumpChallenge(
        tester,
        match: buildChallenge(),
        currentUserId: 'away-manager',
        memberships: const [
          OrganizationMembership(organization: _away, role: 'owner'),
        ],
      );

      expect(find.text('Awaiting reply'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(service.responded, [(matchId: 'c1', accept: true)]);
      expect(
        find.text('Challenge accepted. Your players can join now.'),
        findsOneWidget,
      );
    });

    testWidgets('the host waits while the challenge is pending', (
      tester,
    ) async {
      await pumpChallenge(
        tester,
        match: buildChallenge(),
        currentUserId: 'host-manager',
        memberships: const [
          OrganizationMembership(organization: _host, role: 'owner'),
        ],
      );

      expect(find.text('Cancel challenge'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Join match'), findsNothing);
    });

    testWidgets('outsiders only see that it is a private challenge', (
      tester,
    ) async {
      await pumpChallenge(
        tester,
        match: buildChallenge(),
        currentUserId: 'someone-else',
      );

      expect(find.text('This is a private club challenge.'), findsOneWidget);
      expect(find.text('Join match'), findsNothing);
    });
  });
}
