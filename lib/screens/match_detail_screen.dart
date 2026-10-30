import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/format/money.dart';
import '../core/time/addis_time.dart';
import '../models/match_detail.dart';
import '../models/match_model.dart';
import '../providers/match_detail_provider.dart';
import '../providers/match_feed_provider.dart';
import '../widgets/join_match_sheet.dart';

/// Everything that matters after tapping a game: when and where it is, who is
/// already in, and the one action that fits the viewer's role.
class MatchDetailScreen extends ConsumerStatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.matchId,
    this.initialMatch,
  });

  final String matchId;

  /// The card the user tapped; keeps the header filled while the roster loads.
  final MatchOverview? initialMatch;

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  bool _busy = false;

  Future<void> _join(MatchDetail detail) async {
    final match = detail.match;
    if (match.isFull) {
      final ok = await _confirm(
        title: 'Join the waiting list?',
        body:
            'This game is full. You move into the squad automatically if '
            'someone drops out.',
        confirm: 'Join list',
        dismiss: 'Not now',
      );
      if (ok == true) await _joinNow(match.id);
      return;
    }

    final status = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => JoinMatchSheet(match: match),
    );
    if (status == null || !mounted) return;
    ref.invalidate(matchDetailProvider(widget.matchId));
    _toast(
      status == 'waitlisted'
          ? "You're on the waiting list."
          : 'Spot confirmed. See you on the pitch!',
    );
  }

  Future<void> _joinNow(String matchId) async {
    setState(() => _busy = true);
    try {
      final status = await ref
          .read(joinMatchControllerProvider.notifier)
          .join(matchId);
      ref.invalidate(matchDetailProvider(widget.matchId));
      if (!mounted) return;
      _toast(
        status == 'waitlisted'
            ? "You're on the waiting list."
            : 'Spot confirmed. See you on the pitch!',
      );
    } catch (error) {
      if (mounted) _toast(joinErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final ok = await _confirm(
      title: 'Leave this match?',
      body: 'Your spot goes to the next player on the waiting list.',
      confirm: 'Leave',
      dismiss: 'Stay',
    );
    if (ok == true) {
      await _run(
        () => ref
            .read(matchActionControllerProvider.notifier)
            .leave(widget.matchId),
        done: 'You left the match.',
      );
    }
  }

  Future<void> _shuffle() => _run(
    () => ref
        .read(matchActionControllerProvider.notifier)
        .shuffle(widget.matchId),
    done: 'Teams shuffled.',
  );

  Future<void> _cancel() async {
    final ok = await _confirm(
      title: 'Cancel this match?',
      body:
          'Everyone on the roster will see it as cancelled, and the field '
          'block is freed.',
      confirm: 'Cancel it',
      dismiss: 'Keep match',
    );
    if (ok == true) {
      await _run(
        () => ref
            .read(matchActionControllerProvider.notifier)
            .cancel(widget.matchId),
        done: 'Match cancelled.',
      );
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String done,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _toast(done);
    } catch (error) {
      if (mounted) _toast(matchActionErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirm,
    required String dismiss,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dismiss),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(matchDetailProvider(widget.matchId));
    final match = detail.value?.match ?? widget.initialMatch;

    return Scaffold(
      appBar: AppBar(title: const Text('Match details')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.refresh(matchDetailProvider(widget.matchId).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (match != null) _SummaryCard(match: match),
              const SizedBox(height: 20),
              ...detail.when(
                data: _roster,
                loading: () => const [
                  Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (error, _) => [
                  _ErrorBlock(
                    error: error,
                    onRetry: () =>
                        ref.invalidate(matchDetailProvider(widget.matchId)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _actionBar(detail.value),
    );
  }

  List<Widget> _roster(MatchDetail detail) {
    final theme = Theme.of(context);
    final match = detail.match;
    final notes = match.notes?.trim() ?? '';

    return [
      if (notes.isNotEmpty) ...[
        _NotesCard(notes: notes),
        const SizedBox(height: 20),
      ],
      Row(
        children: [
          Text(
            'Teams',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            '${match.currentPlayers}/${match.maxPlayers} confirmed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _TeamColumn(
              title: 'Team A',
              players: detail.teamA,
              capacity: match.teamSize,
              meId: detail.currentUserId,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TeamColumn(
              title: 'Team B',
              players: detail.teamB,
              capacity: match.teamSize,
              meId: detail.currentUserId,
            ),
          ),
        ],
      ),
      if (detail.waitlist.isNotEmpty) ...[
        const SizedBox(height: 20),
        _WaitlistCard(players: detail.waitlist, meId: detail.currentUserId),
      ],
    ];
  }

  Widget? _actionBar(MatchDetail? detail) {
    if (detail == null) return null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final match = detail.match;
    final Widget child;

    if (match.status == 'cancelled') {
      child = const _StatusLine(
        icon: Icons.event_busy,
        text: 'This match was cancelled.',
      );
    } else if (match.status == 'completed') {
      child = const _StatusLine(
        icon: Icons.flag_outlined,
        text: 'This match has been played.',
      );
    } else if (!detail.isOpen) {
      child = const _StatusLine(
        icon: Icons.schedule,
        text: 'Kickoff has passed.',
      );
    } else if (detail.isOrganizer) {
      child = Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _shuffle,
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _busy ? null : _cancel,
              icon: const Icon(Icons.event_busy),
              label: const Text('Cancel match'),
            ),
          ),
        ],
      );
    } else if (detail.amConfirmed || detail.amWaitlisted) {
      child = OutlinedButton.icon(
        onPressed: _busy ? null : _leave,
        icon: const Icon(Icons.logout),
        label: Text(detail.amWaitlisted ? 'Leave waiting list' : 'Leave match'),
      );
    } else {
      child = FilledButton.icon(
        onPressed: _busy ? null : () => _join(detail),
        icon: Icon(
          match.isFull ? Icons.hourglass_bottom : Icons.person_add_alt_1,
        ),
        label: Text(match.isFull ? 'Join waiting list' : 'Join match'),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: child,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.match});

  final MatchOverview match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final startsAt = addisWall(match.startsAt);
    final endsAt = addisWall(match.endsAt);
    final time = DateFormat('HH:mm');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${DateFormat('EEE, d MMM').format(startsAt)} · '
                  '${time.format(startsAt)} – ${time.format(endsAt)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SpotsChip(match: match),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            match.pitchName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${match.subCityName} · ${match.formatLabel} · '
            'by ${match.organizerName}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                match.pricePerPlayer == 0
                    ? Icons.sports_soccer
                    : Icons.payments_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                match.pricePerPlayer == 0
                    ? 'Free game'
                    : '${etb(match.pricePerPlayer)} ETB per player',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotsChip extends StatelessWidget {
  const _SpotsChip({required this.match});

  final MatchOverview match;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String label;
    final Color background;
    final Color foreground;

    if (match.status == 'cancelled') {
      label = 'Cancelled';
      background = scheme.errorContainer;
      foreground = scheme.onErrorContainer;
    } else if (match.status == 'completed') {
      label = 'Played';
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurfaceVariant;
    } else if (match.isFull) {
      label = 'Full';
      background = scheme.errorContainer;
      foreground = scheme.onErrorContainer;
    } else {
      label = '${match.spotsLeft} spots left!';
      background = match.spotsLeft <= 3
          ? scheme.tertiaryContainer
          : scheme.primaryContainer;
      foreground = match.spotsLeft <= 3
          ? scheme.onTertiaryContainer
          : scheme.onPrimaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.title,
    required this.players,
    required this.capacity,
    required this.meId,
  });

  final String title;
  final List<MatchPlayer> players;
  final int capacity;
  final String? meId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${players.length}/$capacity',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (players.isEmpty)
          Text(
            'No players yet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          for (final player in players)
            _PlayerTile(player: player, isMe: player.userId == meId),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player, required this.isMe});

  final MatchPlayer player;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? scheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isMe
                ? scheme.primary
                : scheme.surfaceContainerHighest,
            child: Text(
              player.initials,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isMe ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitlistCard extends StatelessWidget {
  const _WaitlistCard({required this.players, required this.meId});

  final List<MatchPlayer> players;
  final String? meId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hourglass_bottom,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Waiting list',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'The first to drop out makes room for the top of this list.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < players.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      players[i].fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: players[i].userId == meId
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (players[i].userId == meId)
                    Text(
                      'you',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sticky_note_2_outlined,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'From the organizer',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(notes, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text('Could not load this match', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
