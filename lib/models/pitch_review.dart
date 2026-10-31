class PitchReview {
  final String id;
  final String reviewerName;
  final String? reviewerId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const PitchReview({
    required this.id,
    required this.reviewerName,
    this.reviewerId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory PitchReview.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return PitchReview(
      id: json['id'] as String,
      reviewerName: profile?['full_name'] as String? ?? 'Player',
      reviewerId: json['reviewer_id'] as String?,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// The signed-in player's standing with one field's reviews: whether the
/// player finished a match there, and the review already left, if any.
class PitchReviewState {
  const PitchReviewState({
    required this.canReview,
    this.myRating,
    this.myComment,
  });

  final bool canReview;
  final int? myRating;
  final String? myComment;

  bool get hasReviewed => myRating != null;

  factory PitchReviewState.fromJson(Map<String, dynamic> json) {
    return PitchReviewState(
      canReview: json['can_review'] as bool? ?? false,
      myRating: (json['my_rating'] as num?)?.toInt(),
      myComment: json['my_comment'] as String?,
    );
  }
}
