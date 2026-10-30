import '../../models/sub_city.dart';

/// Sign-up runs before a session exists, and sub_cities is readable only by
/// authenticated users, so the picker uses this static copy of the reference
/// data. It mirrors the sub_cities seed in migration 001.
const List<SubCity> addisSubCities = [
  SubCity(id: 'addis-ketema', nameEn: 'Addis Ketema', nameAm: 'አዲስ ከተማ'),
  SubCity(id: 'akaky-kaliti', nameEn: 'Akaky Kaliti', nameAm: 'አቃቂ ቃሊቲ'),
  SubCity(id: 'arada', nameEn: 'Arada', nameAm: 'አራዳ'),
  SubCity(id: 'bole', nameEn: 'Bole', nameAm: 'ቦሌ'),
  SubCity(id: 'gullele', nameEn: 'Gullele', nameAm: 'ጉለሌ'),
  SubCity(id: 'kirkos', nameEn: 'Kirkos', nameAm: 'ቂርቆስ'),
  SubCity(id: 'kolfe-keranio', nameEn: 'Kolfe Keranio', nameAm: 'ኮልፌ ቀራንዮ'),
  SubCity(id: 'lemi-kura', nameEn: 'Lemi Kura', nameAm: 'ለሚ ኩራ'),
  SubCity(id: 'lideta', nameEn: 'Lideta', nameAm: 'ልደታ'),
  SubCity(
    id: 'nifas-silk-lafto',
    nameEn: 'Nifas Silk-Lafto',
    nameAm: 'ንፋስ ስልክ ላፍቶ',
  ),
  SubCity(id: 'yeka', nameEn: 'Yeka', nameAm: 'የካ'),
];

String subCityNameFor(String id) {
  for (final city in addisSubCities) {
    if (city.id == id) return city.nameEn;
  }
  return id;
}
