import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchside/core/theme/app_theme.dart';
import 'package:pitchside/core/time/addis_time.dart';
import 'package:pitchside/models/match_detail.dart';
import 'package:pitchside/models/match_model.dart';
import 'package:pitchside/models/pitch.dart';
import 'package:pitchside/models/pitch_review.dart';
import 'package:pitchside/models/pitch_slot.dart';
import 'package:pitchside/models/sub_city.dart';
import 'package:pitchside/providers/service_provider.dart';
import 'package:pitchside/screens/create_match_screen.dart';
import 'package:pitchside/services/pitchside_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeCreateMatchService implements PitchsideService {
  final createdMatches = <Map<String, Object?>>[];
  Object? createError;

  static const pitch = Pitch(
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

  @override
  Future<List<Pitch>> getPitches({String? subCityId}) async => [pitch];

  @override
  Future<List<Pitch>> getPitchCards({
    String? subCityId,
    String query = '',
  }) async => [pitch];

  @override
  Future<List<PitchReview>> getPitchReviews(String pitchId) async => const [];

  Object? slotsError;

  /// Two free blocks and one already booked on whatever Addis day is asked for.
  @override
  Future<List<PitchSlot>> getPitchSlots({
    required String pitchId,
    required DateTime day,
  }) async {
    if (slotsError != null) throw slotsError!;
    final sixteen = addisInstant(day, hour: 16);
    final eighteen = addisInstant(day, hour: 18);
    final twenty = addisInstant(day, hour: 20);
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
      PitchSlot(
        start: twenty,
        end: twenty.add(const Duration(hours: 2)),
        isBooked: true,
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
  }) async {
    if (createError != null) throw createError!;
    createdMatches.add({
      'pitchId': pitchId,
      'teamSize': teamSize,
      'startsAt': startsAt,
      'durationMinutes': durationMinutes,
      'pricePerPlayer': pricePerPlayer,
      'notes': notes,
    });
    return {'id': 'match-1'};
  }

  @override
  Future<List<SubCity>> getSubCities() async => [];

  @override
  Future<List<MatchOverview>> getMatches({String? subCityId}) async => [];

  @override
  Future<List<Pitch>> getNearbyPitches({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
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

Future<FakeCreateMatchService> pumpCreateMatch(WidgetTester tester) async {
  final service = FakeCreateMatchService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pitchsideServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CreateMatchScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

Future<void> choosePitch(WidgetTester tester) async {
  await tester.tap(find.text('Pitch'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sarbet Turf House').last);
  await tester.pumpAndSettle();
}

Future<void> chooseBlock(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> submitMatch(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Create match'));
  await tester.tap(find.text('Create match'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('validates pitch and price before calling the backend', (
    tester,
  ) async {
    final service = await pumpCreateMatch(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price per player (ETB)'),
      '-1',
    );
    await submitMatch(tester);

    expect(find.text('Choose a pitch.'), findsOneWidget);
    expect(find.text('Price cannot be negative.'), findsOneWidget);
    expect(service.createdMatches, isEmpty);
  });

  testWidgets('submits the organizer match details', (tester) async {
    final service = await pumpCreateMatch(tester);

    await choosePitch(tester);
    await chooseBlock(tester, '16:00 – 18:00');
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('More players per side'));
      await tester.pump();
    }
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price per player (ETB)'),
      '200',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notes (optional)'),
      '  Bring a dark shirt  ',
    );
    await submitMatch(tester);

    expect(service.createdMatches, hasLength(1));
    final created = service.createdMatches.single;
    expect(created['pitchId'], 'pitch-1');
    expect(created['teamSize'], 7);
    expect(created['durationMinutes'], 120);
    expect(created['pricePerPlayer'], 200.0);
    expect(created['notes'], 'Bring a dark shirt');
    final kickoff = created['startsAt'] as DateTime;
    // The block the organizer tapped is the block the match is booked into,
    // in Addis time, whichever timezone the phone runs on.
    final wall = addisWall(kickoff);
    expect((wall.hour, wall.minute), (16, 0));
    expect(wall.isAfter(DateTime.now()), isTrue);
  });

  testWidgets('a picked slot sets the kickoff and the block length', (
    tester,
  ) async {
    final service = FakeCreateMatchService();
    final kickoff = addisInstant(
      addisToday().add(const Duration(days: 2)),
      hour: 18,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pitchsideServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CreateMatchScreen(
            initialPitch: FakeCreateMatchService.pitch,
            initialStartsAt: kickoff,
            initialDurationMinutes: 120,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sarbet Turf House'), findsOneWidget);
    expect(find.text('Bole'), findsOneWidget);
    expect(find.text('120 minutes'), findsOneWidget);
    expect(find.textContaining('6:00'), findsWidgets);
    expect(find.textContaining('2-hour block at the field'), findsOneWidget);
    expect(find.textContaining('4,000 ETB'), findsOneWidget);

    await submitMatch(tester);
    expect(service.createdMatches.single['durationMinutes'], 120);
    expect(service.createdMatches.single['startsAt'], kickoff);
  });

  testWidgets('lists only the free blocks of the chosen field', (tester) async {
    await pumpCreateMatch(tester);

    expect(
      find.text('Pick a field to see the blocks it sells.'),
      findsOneWidget,
    );

    await choosePitch(tester);

    expect(find.text('16:00 – 18:00'), findsOneWidget);
    expect(find.text('18:00 – 20:00'), findsOneWidget);
    expect(find.text('20:00 – 22:00'), findsNothing);
  });

  testWidgets('will not create a match without a block', (tester) async {
    final service = await pumpCreateMatch(tester);

    await choosePitch(tester);
    await submitMatch(tester);

    expect(find.text('Pick a free block at this field.'), findsOneWidget);
    expect(service.createdMatches, isEmpty);
  });

  testWidgets('offers every team size from 5v5 to 11v11', (tester) async {
    final service = await pumpCreateMatch(tester);

    await choosePitch(tester);
    await chooseBlock(tester, '18:00 – 20:00');
    expect(find.text('5v5'), findsOneWidget);
    expect(find.text('10 players'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
          .onPressed,
      isNull,
    );

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('More players per side'));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('11v11'), findsOneWidget);
    expect(find.text('22 players'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price per player (ETB)'),
      '200',
    );
    await tester.pumpAndSettle();
    expect(find.text('22 players × 200 ETB = 4,400 ETB'), findsOneWidget);

    await submitMatch(tester);
    expect(service.createdMatches.single['teamSize'], 11);
  });

  testWidgets('shows a friendly error when creation fails', (tester) async {
    final service = await pumpCreateMatch(tester);
    service.createError = PostgrestException(
      message: 'kickoff must be in the future',
      code: '45008',
    );

    await choosePitch(tester);
    await chooseBlock(tester, '16:00 – 18:00');
    await submitMatch(tester);

    expect(find.text('Choose a kickoff time in the future.'), findsOneWidget);
    expect(service.createdMatches, isEmpty);
    expect(find.text('Create match'), findsOneWidget);
  });
}
