import 'package:flutter_test/flutter_test.dart';
import 'package:pitchside/core/location/google_maps.dart';

void main() {
  test('uses the published pin as the destination', () {
    final uri = googleMapsDirectionsUri(
      name: 'Bole Atlas 5-A-Side',
      address: 'Atlas, behind Atlas Hotel',
      subCityName: 'Bole',
      latitude: 8.999,
      longitude: 38.786,
    );

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['destination'], '8.999,38.786');
  });

  test('searches by name and address when no pin exists', () {
    final uri = googleMapsDirectionsUri(
      name: '22 Golagul',
      address: 'Bole, Woreda 04',
      subCityName: 'Bole',
    );

    expect(
      uri.queryParameters['destination'],
      '22 Golagul, Bole, Woreda 04, Addis Ababa',
    );
  });

  test('adds the sub-city when the address does not name it', () {
    final uri = googleMapsDirectionsUri(
      name: 'Sanford',
      address: 'Woreda 07',
      subCityName: 'Arada',
    );

    expect(
      uri.queryParameters['destination'],
      'Sanford, Woreda 07, Arada, Addis Ababa',
    );
  });

  test('falls back to the name and sub-city without an address', () {
    final uri = googleMapsDirectionsUri(
      name: 'Berta Meda',
      subCityName: 'Akaky Kaliti',
    );

    expect(
      uri.queryParameters['destination'],
      'Berta Meda, Akaky Kaliti, Addis Ababa',
    );
  });
}
