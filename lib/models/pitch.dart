class Pitch {
  final String id;
  final String name;
  final String subCityId;
  final String? address;
  final String? woreda;
  final String? description;
  final String? imageUrl;
  final List<String> amenities;
  final List<String> houseRules;
  final double? ratingAvg;
  final int reviewCount;
  final double? directoryRating;
  final int directoryReviewCount;
  final double? latitude;
  final double? longitude;
  final String surface;
  final double pricePerHour;
  final int blockHours;
  final bool? hasFloodlights;
  final String? contactPhone;
  final bool isActive;
  final double? distanceMeters;

  const Pitch({
    required this.id,
    required this.name,
    required this.subCityId,
    this.address,
    this.woreda,
    this.description,
    this.imageUrl,
    this.amenities = const [],
    this.houseRules = const [],
    this.ratingAvg,
    this.reviewCount = 0,
    this.directoryRating,
    this.directoryReviewCount = 0,
    this.latitude,
    this.longitude,
    required this.surface,
    required this.pricePerHour,
    this.blockHours = 2,
    this.hasFloodlights,
    this.contactPhone,
    required this.isActive,
    this.distanceMeters,
  });

  factory Pitch.fromJson(Map<String, dynamic> json) {
    return Pitch(
      id: json['id'] as String? ?? json['pitch_id'] as String,
      name: json['name'] as String? ?? json['pitch_name'] as String,
      subCityId: json['sub_city_id'] as String,
      address: json['address'] as String?,
      woreda: json['woreda'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      amenities: _stringList(json['amenities']),
      houseRules: _stringList(json['house_rules']),
      ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      directoryRating: (json['directory_rating'] as num?)?.toDouble(),
      directoryReviewCount:
          (json['directory_review_count'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      surface: json['surface'] as String,
      pricePerHour: (json['price_per_hour'] as num).toDouble(),
      blockHours: (json['booking_block_hours'] as num?)?.toInt() ?? 2,
      hasFloodlights: json['has_floodlights'] as bool?,
      contactPhone: json['contact_phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      distanceMeters: (json['distance_m'] as num?)?.toDouble(),
    );
  }

  /// Pitchside's own player reviews.
  bool get hasPlayerReviews => ratingAvg != null && reviewCount > 0;

  /// What the card shows: our players' rating once there is one, otherwise the
  /// aggregate the city directory publishes.
  double? get displayRating => ratingAvg ?? directoryRating;

  /// Null while a venue has no ratings from either source; the UI shows
  /// "New field" instead of an invented score.
  bool get isUnrated => displayRating == null;

  String get surfaceLabel => surface
      .replaceAll('_', ' ')
      .replaceFirstMapped(RegExp('^[a-z]'), (m) => m.group(0)!.toUpperCase());

  double get blockPrice => pricePerHour * blockHours;

  /// Identity is the primary key, so a pitch fetched by the directory and the
  /// same pitch fetched for the picker compare equal.
  @override
  bool operator ==(Object other) => other is Pitch && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

List<String> _stringList(Object? value) {
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const [];
}
