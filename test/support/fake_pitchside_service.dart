import 'package:pitchside/services/pitchside_service.dart';

/// Base for test doubles. Every call a test does not override fails loudly
/// with the method name, so a screen reaching for a new endpoint shows up as a
/// clear error instead of a silent fake answer.
class FakePitchsideService implements PitchsideService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not faked in this test.',
    );
  }
}
