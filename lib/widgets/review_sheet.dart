import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

typedef ReviewDraft = ({int rating, String? comment});

const _ratingLabels = ['Poor', 'Below par', 'Okay', 'Good', 'Excellent'];

/// Star picker and optional comment. Pops with the draft, or null when the
/// player backs out; the calling screen does the write.
class ReviewSheet extends StatefulWidget {
  const ReviewSheet({
    super.key,
    required this.pitchName,
    this.initialRating,
    this.initialComment,
  });

  final String pitchName;
  final int? initialRating;
  final String? initialComment;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  late int _rating = widget.initialRating ?? 0;
  late final TextEditingController _comment = TextEditingController(
    text: widget.initialComment ?? '',
  );

  bool get _editing => widget.initialRating != null;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating == 0) return;
    final text = _comment.text.trim();
    Navigator.of(
      context,
    ).pop<ReviewDraft>((rating: _rating, comment: text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editing ? 'Update your review' : 'How was the field?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.pitchName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      onPressed: () => setState(() => _rating = star),
                      tooltip: '$star star${star == 1 ? '' : 's'}',
                      iconSize: 38,
                      color: AppColors.star,
                      icon: Icon(
                        _rating >= star
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                      ),
                    ),
                ],
              ),
              Text(
                _rating == 0
                    ? 'Tap a star to rate'
                    : _ratingLabels[_rating - 1],
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _rating == 0
                      ? scheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _comment,
                maxLength: 500,
                maxLines: 4,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  hintText:
                      'Surface, floodlights, changing rooms, finding the gate…',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _rating == 0 ? null : _submit,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(_editing ? 'Save review' : 'Post review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
