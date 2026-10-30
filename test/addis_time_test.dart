import 'package:flutter_test/flutter_test.dart';
import 'package:pitchside/core/time/addis_time.dart';

void main() {
  test('renders an instant as Addis wall-clock time', () {
    final wall = addisWall(DateTime.utc(2026, 10, 31, 21, 30));

    expect(
      (wall.year, wall.month, wall.day, wall.hour, wall.minute),
      (2026, 11, 1, 0, 30),
    );
  });

  test('builds the instant of an Addis wall-clock kickoff', () {
    final kickoff = addisInstant(DateTime.utc(2026, 11, 1), hour: 16);

    expect(kickoff, DateTime.utc(2026, 11, 1, 13));
    expect(addisWall(kickoff).hour, 16);
  });

  test('folds a late instant into the next Addis day', () {
    expect(
      addisDate(DateTime.utc(2026, 10, 31, 22)),
      DateTime.utc(2026, 11, 1),
    );
  });
}
