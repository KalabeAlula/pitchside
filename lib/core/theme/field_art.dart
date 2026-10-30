/// Bundled venue photography used when a pitch has no photo of its own.
/// Fields are assigned artwork deterministically from their id, so a card never
/// changes its picture between launches.
abstract final class FieldArt {
  static const hero = 'assets/images/pitch_hero.jpg';

  static const _cards = [
    'assets/images/pitch_art_1.jpg',
    'assets/images/pitch_art_2.jpg',
    'assets/images/pitch_art_3.jpg',
  ];

  static String forPitch(String id) {
    final seed = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return _cards[seed % _cards.length];
  }
}
