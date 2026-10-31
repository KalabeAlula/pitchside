import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pitch_review.dart';
import '../providers/fields_provider.dart';
import '../providers/service_provider.dart';
import 'review_sheet.dart';

/// "Rate this field" / "Edit your review" for a player the database allows to
/// review. The caller decides where it belongs; the button handles the sheet,
/// the write, and refreshing the field's rating.
class FieldReviewButton extends ConsumerStatefulWidget {
  const FieldReviewButton({
    super.key,
    required this.pitchId,
    required this.pitchName,
    required this.state,
    this.rateLabel = 'Rate this field',
    this.icon = Icons.star_outline_rounded,
  });

  final String pitchId;
  final String pitchName;
  final PitchReviewState state;
  final String rateLabel;
  final IconData icon;

  @override
  ConsumerState<FieldReviewButton> createState() => _FieldReviewButtonState();
}

class _FieldReviewButtonState extends ConsumerState<FieldReviewButton> {
  bool _busy = false;

  Future<void> _open() async {
    final draft = await showModalBottomSheet<ReviewDraft>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ReviewSheet(
        pitchName: widget.pitchName,
        initialRating: widget.state.myRating,
        initialComment: widget.state.myComment,
      ),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(pitchsideServiceProvider)
          .submitPitchReview(
            pitchId: widget.pitchId,
            rating: draft.rating,
            comment: draft.comment,
          );
      if (!mounted) return;
      ref.invalidate(pitchReviewStateProvider(widget.pitchId));
      ref.invalidate(pitchReviewsProvider(widget.pitchId));
      ref.invalidate(fieldsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review saved. Thanks for helping other players.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_reviewError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: _busy ? null : _open,
      icon: _busy
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(widget.icon, size: 18),
      label: Text(
        widget.state.hasReviewed ? 'Edit your review' : widget.rateLabel,
      ),
    );
  }
}

String _reviewError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('only players who finished')) {
    return 'Only players who finished a match here can review.';
  }
  if (text.contains('review is too long')) {
    return 'Keep the comment under 500 characters.';
  }
  return 'Could not save your review. Check your connection and try again.';
}
