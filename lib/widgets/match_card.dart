import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/format/money.dart';
import '../core/time/addis_time.dart';
import '../models/match_model.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    required this.onJoin,
    required this.onOpen,
  });

  final MatchOverview match;

  /// Always called, even for full matches: the screen decides what to do.
  final VoidCallback onJoin;

  /// Opens the match page: roster, waiting list and role-aware actions.
  final VoidCallback onOpen;

  String get _priceLabel =>
      match.pricePerPlayer == 0 ? 'Free' : '${etb(match.pricePerPlayer)} ETB';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final startsAt = addisWall(match.startsAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('EEE, d MMM').format(startsAt)} · '
                    '${DateFormat('HH:mm').format(startsAt)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _SpotsBadge(spotsLeft: match.spotsLeft),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                match.pitchName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${match.subCityName} · ${match.formatLabel} · '
                'by ${match.organizerName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    _priceLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    ' / player',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: onJoin,
                    icon: Icon(
                      match.isFull ? Icons.group : Icons.person_add_alt_1,
                      size: 18,
                    ),
                    label: Text(match.isFull ? 'Full' : 'Join match'),
                    style: match.isFull
                        ? FilledButton.styleFrom(
                            backgroundColor: scheme.surfaceContainerHighest,
                            foregroundColor: scheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotsBadge extends StatelessWidget {
  const _SpotsBadge({required this.spotsLeft});

  final int spotsLeft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFull = spotsLeft <= 0;
    final isFilling = !isFull && spotsLeft <= 3;

    final background = isFull
        ? scheme.errorContainer
        : isFilling
        ? scheme.tertiaryContainer
        : scheme.primaryContainer;
    final foreground = isFull
        ? scheme.onErrorContainer
        : isFilling
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isFull ? 'Full' : '$spotsLeft spots left!',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}
