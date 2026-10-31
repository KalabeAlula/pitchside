import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/time/addis_time.dart';
import '../models/player_standing.dart';
import '../providers/standing_provider.dart';

/// The player's fair-play record: where the reliability score stands, whether
/// public games are paused, and the rules that move it.
class MyStandingScreen extends ConsumerWidget {
  const MyStandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standing = ref.watch(myStandingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My standing',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(myStandingProvider),
          ),
        ],
      ),
      body: standing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _StandingError(
          error: error,
          onRetry: () => ref.invalidate(myStandingProvider),
        ),
        data: (value) => RefreshIndicator(
          onRefresh: () => ref.refresh(myStandingProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ScoreCard(standing: value),
              if (value.isSuspended) ...[
                const SizedBox(height: 12),
                _SuspensionCard(until: value.suspendedUntil!),
              ] else if (value.suspensionEnded) ...[
                const SizedBox(height: 12),
                const _NoticeCard(
                  icon: Icons.lock_open,
                  title: 'Public games are open again',
                  body:
                      'The week is up — you can join public pickups. Fix the '
                      'penalty or keep a clean record to lift the score.',
                ),
              ],
              const SizedBox(height: 12),
              _StatsCard(standing: value),
              const SizedBox(height: 12),
              const _RulesCard(),
            ],
          ),
        ),
      ),
    );
  }
}

String _scoreStatus(PlayerStanding standing) {
  if (standing.isSuspended) return 'Suspended';
  if (standing.suspensionEnded) return 'Suspension over';
  if (standing.isAtRisk) return 'At risk';
  if (standing.score < 50) return 'Below 50';
  return 'In good standing';
}

Color _scoreColor(PlayerStanding standing, ColorScheme scheme) {
  if (standing.isSuspended || standing.score < 50) return scheme.error;
  if (standing.suspensionEnded || standing.isAtRisk) {
    return AppColors.floodlight;
  }
  return scheme.primary;
}

String _scoreMessage(PlayerStanding standing) {
  if (standing.isSuspended) {
    return 'Public pickup games are paused until the date below. Club games '
        'and challenges are not affected.';
  }
  if (standing.suspensionEnded) {
    return standing.score < 50
        ? 'Public games are open again, but your score is still below 50.'
        : 'The week is up — public games are open to you again.';
  }
  if (standing.isAtRisk) {
    return 'One more late cancellation or no-show drops you below 50 and '
        'pauses public games.';
  }
  if (standing.score < 50) {
    return 'Your score is below 50. Turning up keeps it from falling further.';
  }
  return 'Turning up and giving notice when you cannot keeps this high.';
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.standing});

  final PlayerStanding standing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _scoreColor(standing, scheme);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reliability score',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _scoreStatus(standing),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${standing.score}',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/ 100',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: standing.score / 100,
                minHeight: 8,
                color: color,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _scoreMessage(standing),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuspensionCard extends StatelessWidget {
  const _SuspensionCard({required this.until});

  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rejoin = DateFormat('EEE d MMM · HH:mm').format(addisWall(until));

    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_clock, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Public games paused',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You can join public pickups again from '
                    '$rejoin $eatLabel.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.standing});

  final PlayerStanding standing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: _StatTile(
                value: '${standing.matchesPlayed}',
                label: 'Games played',
              ),
            ),
            SizedBox(
              height: 40,
              child: VerticalDivider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            Expanded(
              child: _StatTile(value: '${standing.noShows}', label: 'No-shows'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  static const _rules = [
    'Everyone starts at 100.',
    'Leaving a confirmed spot inside 3 hours of kickoff: −25.',
    'A no-show marked by the organizer: −25.',
    'Below 50 pauses public games for 7 days. Club games carry on.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How the score works',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final rule in _rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(rule, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'The score only moves back when a penalty is corrected — the '
              'organizer fixing a roll call, or you rejoining a match you left. '
              'Turning up keeps it steady but does not add points.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingError extends StatelessWidget {
  const _StandingError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load your standing',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
