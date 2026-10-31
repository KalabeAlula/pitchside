import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchside/core/theme/app_theme.dart';
import 'package:pitchside/models/player_standing.dart';
import 'package:pitchside/providers/service_provider.dart';
import 'package:pitchside/screens/my_standing_screen.dart';

import 'support/fake_pitchside_service.dart';

class StandingFakeService extends FakePitchsideService {
  StandingFakeService(this.standing);

  final PlayerStanding standing;

  @override
  Future<PlayerStanding> getMyStanding() async => standing;
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
    expect(find.text('Public games paused'), findsNothing);
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
