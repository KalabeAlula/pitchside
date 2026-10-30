import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitchside/core/theme/app_theme.dart';
import 'package:pitchside/providers/auth_provider.dart';
import 'package:pitchside/providers/service_provider.dart';
import 'package:pitchside/screens/auth/auth_gate.dart';
import 'package:pitchside/screens/auth/sign_in_screen.dart';
import 'package:pitchside/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'match_feed_screen_test.dart' show FakePitchsideService;

class FakeAuthService implements AuthService {
  Map<String, dynamic>? signUpCall;
  Map<String, String>? signInCall;
  Object? errorToThrow;
  bool signOutCalled = false;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? subCityId,
    String level = 'beginner',
  }) async {
    signUpCall = {
      'email': email,
      'password': password,
      'full_name': fullName,
      'phone': phone,
      'sub_city_id': subCityId,
      'level': level,
    };
    if (errorToThrow != null) throw errorToThrow!;
    return AuthResponse();
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    signInCall = {'email': email, 'password': password};
    if (errorToThrow != null) throw errorToThrow!;
    return AuthResponse();
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Session? get currentSession => null;
}

Future<void> pumpSignIn(WidgetTester tester, FakeAuthService auth) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      child: MaterialApp(theme: AppTheme.light(), home: const SignInScreen()),
    ),
  );
}

void main() {
  group('AuthGate', () {
    testWidgets('shows sign-in when there is no session', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            signedInProvider.overrideWith((ref) => Stream.value(false)),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pickup football in Addis Ababa'), findsOneWidget);
      expect(find.text('Pitchside'), findsOneWidget);
    });

    testWidgets('shows the field directory when signed in', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            signedInProvider.overrideWith((ref) => Stream.value(true)),
            pitchsideServiceProvider.overrideWithValue(
              FakePitchsideService(subCities: const [], matches: const []),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find your field'), findsOneWidget);
      expect(find.text('Fields'), findsOneWidget);
      expect(find.text('Games'), findsOneWidget);
      expect(find.text('22 Golagul'), findsWidgets);
    });
  });

  group('SignInScreen', () {
    testWidgets('validates before calling the backend', (tester) async {
      final auth = FakeAuthService();
      await pumpSignIn(tester, auth);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter a password'), findsOneWidget);
      expect(auth.signInCall, isNull);
    });

    testWidgets('sends trimmed credentials', (tester) async {
      final auth = FakeAuthService();
      await pumpSignIn(tester, auth);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        '  abebe@example.com  ',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(auth.signInCall, {
        'email': 'abebe@example.com',
        'password': 'password123',
      });
    });

    testWidgets('surfaces a friendly error on bad credentials', (tester) async {
      final auth = FakeAuthService()
        ..errorToThrow = AuthException('Invalid login credentials');
      await pumpSignIn(tester, auth);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'abebe@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'wrong-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Wrong email or password.'), findsOneWidget);
    });
  });

  group('SignUpScreen', () {
    Future<void> openSignUp(WidgetTester tester, FakeAuthService auth) async {
      await pumpSignIn(tester, auth);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
    }

    testWidgets('sends profile metadata for the handle_new_user trigger', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await openSignUp(tester, auth);

      await tester.enterText(find.byType(TextFormField).at(0), 'Abebe Kebede');
      await tester.enterText(find.byType(TextFormField).at(1), '0911234567');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'abebe@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(3), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(auth.signUpCall, {
        'email': 'abebe@example.com',
        'password': 'password123',
        'full_name': 'Abebe Kebede',
        'phone': '0911234567',
        'sub_city_id': null,
        'level': 'beginner',
      });
      expect(
        find.text('Account created. Confirm your email, then sign in.'),
        findsOneWidget,
      );
    });

    testWidgets('rejects a weak password without calling the backend', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await openSignUp(tester, auth);

      await tester.enterText(find.byType(TextFormField).at(0), 'Abebe Kebede');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'abebe@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(3), 'short');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(auth.signUpCall, isNull);
    });

    testWidgets('rejects a malformed phone number', (tester) async {
      final auth = FakeAuthService();
      await openSignUp(tester, auth);

      await tester.enterText(find.byType(TextFormField).at(0), 'Abebe Kebede');
      await tester.enterText(find.byType(TextFormField).at(1), '12345');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'abebe@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(3), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a valid Ethiopian mobile number'),
        findsOneWidget,
      );
      expect(auth.signUpCall, isNull);
    });
  });
}
