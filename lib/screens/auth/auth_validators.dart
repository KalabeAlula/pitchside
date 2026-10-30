String? emailValidator(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? passwordValidator(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Enter a password';
  if (password.length < 8) return 'Use at least 8 characters';
  return null;
}

String? fullNameValidator(String? value) {
  final name = (value ?? '').trim();
  if (name.length < 2) return 'Enter your full name';
  return null;
}

/// Optional field, but when filled it must be an Ethiopian mobile number.
/// Accepts 09xx..., 9xx..., 251xxx... and +251 xxx xxx xxx.
String? phoneValidator(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return null;
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  final valid = RegExp(r'^(0[79][0-9]{8}|251[79][0-9]{8}|[79][0-9]{8})$')
      .hasMatch(digits);
  return valid ? null : 'Enter a valid Ethiopian mobile number';
}
