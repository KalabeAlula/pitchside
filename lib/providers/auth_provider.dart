import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// True whenever a session exists. Kept as a bool so the gate is trivial to
/// override in tests and never rebuilds on token refreshes.
final signedInProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(authServiceProvider)
      .authStateChanges
      .map((state) => state.session != null),
);

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _run(
      () => ref
          .read(authServiceProvider)
          .signIn(email: email, password: password),
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? subCityId,
    String level = 'beginner',
  }) {
    return _run(
      () => ref
          .read(authServiceProvider)
          .signUp(
            email: email,
            password: password,
            fullName: fullName,
            phone: phone,
            subCityId: subCityId,
            level: level,
          ),
    );
  }

  Future<AuthResponse> _run(Future<AuthResponse> Function() action) async {
    state = const AsyncLoading();
    try {
      final response = await action();
      state = const AsyncData(null);
      return response;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() => ref.read(authServiceProvider).signOut();
}

String authErrorMessage(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (message.contains('already registered')) {
      return 'An account with this email already exists. Sign in instead.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirm your email first, then sign in.';
    }
    if (message.contains('password')) {
      return 'Password is too weak. Use at least 8 characters.';
    }
    if (message.contains('rate limit')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    return error.message;
  }
  return 'No connection. Check your internet and try again.';
}
