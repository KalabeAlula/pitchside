import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/format/money.dart';
import '../core/time/addis_time.dart';
import '../models/match_model.dart';
import '../providers/match_feed_provider.dart';

/// Confirmation step before a player commits to a match.
/// Pops with the status the server assigned — `confirmed`, or `waitlisted` when
/// the roster filled up first — and with null when dismissed.
class JoinMatchSheet extends ConsumerStatefulWidget {
  const JoinMatchSheet({super.key, required this.match});

  final MatchOverview match;

  @override
  ConsumerState<JoinMatchSheet> createState() => _JoinMatchSheetState();
}

class _JoinMatchSheetState extends ConsumerState<JoinMatchSheet> {
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final status = await ref
          .read(joinMatchControllerProvider.notifier)
          .join(widget.match.id);
      if (mounted) Navigator.of(context).pop(status);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = joinErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = widget.match;
    final startsAt = addisWall(match.startsAt);
    final priceLabel = match.pricePerPlayer == 0
        ? 'Free game — no payment needed'
        : '${etb(match.pricePerPlayer)} ETB per player, '
              'paid to the organizer';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirm your spot',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${match.spotsLeft} of ${match.maxPlayers} spots still open',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _DetailRow(
              icon: Icons.location_on_outlined,
              text: '${match.pitchName}, ${match.subCityName}',
            ),
            _DetailRow(
              icon: Icons.schedule,
              text:
                  '${DateFormat('EEEE, d MMMM').format(startsAt)} '
                  'at ${DateFormat('HH:mm').format(startsAt)}',
            ),
            _DetailRow(
              icon: Icons.sports_soccer,
              text: match.isOrgMatch
                  ? '${match.formatLabel} · ${match.clubLabel}'
                  : '${match.formatLabel} · organized by ${match.organizerName}',
            ),
            if (match.isOrgMatch)
              _DetailRow(
                icon: Icons.groups_outlined,
                text: match.isInternal
                    ? 'Club game: only ${match.organizationName ?? 'club'} '
                          'members play.'
                    : 'Club challenge: your squad fills your club side.',
              ),
            _DetailRow(icon: Icons.payments_outlined, text: priceLabel),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _confirm,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm spot'),
            ),
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
