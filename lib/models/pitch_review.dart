class PitchReview {
  final String id;
  final String reviewerName;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const PitchReview({
    required this.id,
    required this.reviewerName,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory PitchReview.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return PitchReview(
      id: json['id'] as String,
      reviewerName: profile?['full_name'] as String? ?? 'Player',
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
