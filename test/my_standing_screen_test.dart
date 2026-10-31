import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchside/core/theme/app_theme.dart';
import 'package:pitchside/models/past_match.dart';
import 'package:pitchside/models/player_standing.dart';
import 'package:pitchside/providers/service_provider.dart';
import 'package:pitchside/screens/my_standing_screen.dart';

import 'support/fake_pitchside_service.dart';

class StandingFakeService extends FakePitchsideService {
  StandingFakeService(this.standing, {this.pastMatches = const []});

  final PlayerStanding standing;
  final List<PastMatch> pastMatches;

  @override
  Future<PlayerStanding> getMyStanding() async => standing;

  @override
  Future<List<PastMatch>> getMyPastMatches() async => pastMatches;
}

class FailingStandingService extends FakePitchsideService {
  @override
  Future<PlayerStanding> getMyStanding() async {
    throw Exception('offline');
  }
}

Widget buildScreen(FakePitchsideService service) {
  return ProviderScope(
    overrides: [pitchsideServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const MyStandingScreen(),
    ),
  );
}

void main() {
  testWidgets('shows a clean record in good standing', (tester) async {
    final service = StandingFakeService(
      const PlayerStanding(
        score: 100,
        suspendedUntil: null,
        matchesPlayed: 6,
        noShows: 0,
      ),
    );

    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();

    expect(find.text('My standing'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('/ 100'), findsOneWidget);
    expect(find.text('In good standing'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Games played'), findsOneWidget);
    expect(find.text('No-shows'), findsOneWidget);
    expect(find.text('How the score works'), findsOneWidget);
    expect(
      find.text('Completed matches will appear here after your first game.'),
      findsOneWidget,
    );
    expect(find.text('Public games paused'), findsNothing);
  });

  testWidgets('lists past matches with attendance', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = StandingFakeService(
      const PlayerStanding(
        score: 100,
        suspendedUntil: null,
        matchesPlayed: 8,
        noShows: 1,
      ),
      pastMatches: [
        PastMatch(
          id: 'm1',
          pitchId: 'p1',
          pitchName: 'Sarbet Turf House',
          subCityName: 'Kirkos',
          startsAt: DateTime.utc(2026, 10, 25, 16),
          endsAt: DateTime.utc(2026, 10, 25, 17),
          team: 'A',
          attended: true,
        ),
        PastMatch(
          id: 'm2',
          pitchId: 'p2',
          pitchName: 'Kazanchis Turf',
          subCityName: 'Kirkos',
          startsAt: DateTime.utc(2026, 10, 18, 7),
          endsAt: DateTime.utc(2026, 10, 18, 8),
          team: 'B',
          attended: false,
        ),
      ],
    );

    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();

    expect(find.text('Past matches'), findsOneWidget);
    expect(find.text('Sarbet Turf House'), findsOneWidget);
    expect(find.text('Sun 25 Oct · 19:00–20:00 EAT'), findsOneWidget);
    expect(find.text('Kirkos · Team A'), findsOneWidget);
    expect(find.text('Played'), findsOneWidget);
    expect(find.text('Kazanchis Turf'), findsOneWidget);
    expect(find.text('Sun 18 Oct · 10:00–11:00 EAT'), findsOneWidget);
    expect(find.text('Kirkos · Team B'), findsOneWidget);
    expect(find.text('No-show'), findsOneWidget);
    expect(
      find.text('Completed matches will appear here after your first game.'),
      findsNothing,
    );
  });

  testWidgets('an active suspension shows the EAT rejoin time', (tester) async {
    final service = StandingFakeService(
      PlayerStanding(
        score: 25,
        suspendedUntil: DateTime.utc(2030, 1, 15, 9, 30),
        matchesPlayed: 8,
        noShows: 3,
      ),
    );

    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();

    expect(find.text('Suspended'), findsOneWidget);
    expect(find.text('Public games paused'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(
      find.text(
        'You can join public pickups again from Tue 15 Jan · 12:30 EAT.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('paused until the date below'), findsOneWidget);
  });

  testWidgets('an expired suspension reopens public games', (tester) async {
    final service = StandingFakeService(
      PlayerStanding(
        score: 25,
        suspendedUntil: DateTime.utc(2020, 1, 1),
        matchesPlayed: 8,
        noShows: 3,
      ),
    );

    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();

    expect(find.text('Suspension over'), findsOneWidget);
    expect(find.text('Public games are open again'), findsOneWidget);
    expect(find.text('Public games paused'), findsNothing);
    expect(find.textContaining('still below 50'), findsOneWidget);
  });

  testWidgets('one penalty away reads as at risk', (tester) async {
    final service = StandingFakeService(
      const PlayerStanding(
        score: 74,
        suspendedUntil: null,
        matchesPlayed: 10,
        noShows: 1,
      ),
    );

    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();

    expect(find.text('At risk'), findsOneWidget);
    expect(find.textContaining('One more late cancellation'), findsOneWidget);
  });

  testWidgets('renders the server error with a retry', (tester) async {
    await tester.pumpWidget(buildScreen(FailingStandingService()));
    await tester.pumpAndSettle();

    expect(find.text('Could not load your standing'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('renders in dark mode', (tester) async {
    final service = StandingFakeService(
      const PlayerStanding(
        score: 100,
        suspendedUntil: null,
        matchesPlayed: 2,
        noShows: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [pitchsideServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const MyStandingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Reliability score'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(find.text('In good standing'), findsOneWidget);
  });
}
