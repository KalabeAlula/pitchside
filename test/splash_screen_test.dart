import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchside/providers/auth_provider.dart';
import 'package:pitchside/screens/auth/sign_in_screen.dart';
import 'package:pitchside/screens/splash_screen.dart';

Widget buildGate({Duration minimum = const Duration(milliseconds: 600)}) {
  return ProviderScope(
    overrides: [signedInProvider.overrideWith((ref) => Stream.value(false))],
    child: MaterialApp(home: StartupGate(minimumSplash: minimum)),
  );
}

void main() {
  testWidgets('splash shows the mark, wordmark and a loading cue', (
    tester,
  ) async {
    await tester.pumpWidget(buildGate());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('PITCHSIDE'), findsOneWidget);
    expect(find.text('ADDIS ABABA'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);

    final overlay = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        )
        .last;
    expect(overlay.value.systemNavigationBarColor, Colors.transparent);
    expect(overlay.value.systemNavigationBarContrastEnforced, isFalse);
  });

  testWidgets('hands off to the app once the beat and session resolve', (
    tester,
  ) async {
    await tester.pumpWidget(buildGate());
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('PITCHSIDE'), findsNothing);
  });
}
