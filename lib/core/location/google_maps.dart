import 'package:url_launcher/url_launcher.dart';

/// Google Maps directions link for a venue.
///
/// A published pin is the exact destination. Without one — every field in the
/// city directory currently lacks coordinates — Maps searches by the venue's
/// name and address instead, so the button still lands somewhere useful.
Uri googleMapsDirectionsUri({
  required String name,
  String? address,
  String? subCityName,
  double? latitude,
  double? longitude,
}) {
  final destination = latitude != null && longitude != null
      ? '$latitude,$longitude'
      : _searchTarget(name, address, subCityName);

  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': destination,
  });
}

String _searchTarget(String name, String? address, String? subCityName) {
  final trimmedAddress = address?.trim();
  final parts = <String>[
    name,
    if (trimmedAddress != null && trimmedAddress.isNotEmpty) trimmedAddress,
    if (subCityName != null &&
        !(trimmedAddress ?? '').toLowerCase().contains(
          subCityName.toLowerCase(),
        ))
      subCityName,
    'Addis Ababa',
  ];
  return parts.join(', ');
}

/// Opens the link in the Google Maps app when installed, otherwise in the
/// browser. Returns false so the caller can show a message instead of failing
/// silently.
Future<bool> openGoogleMaps(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
