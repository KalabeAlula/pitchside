import 'package:flutter_test/flutter_test.dart';
import 'package:pitchside/models/sub_city.dart';

void main() {
  test('SubCity model parses correctly', () {
    final subCity = SubCity.fromJson({
      'id': 'bole',
      'name_en': 'Bole',
      'name_am': 'ቦሌ',
    });

    expect(subCity.id, 'bole');
    expect(subCity.nameEn, 'Bole');
    expect(subCity.nameAm, 'ቦሌ');
  });
}
