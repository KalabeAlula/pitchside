import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time/addis_time.dart';
import '../core/time/kickoff_status.dart';
import '../providers/clock_provider.dart';
import '../providers/match_feed_provider.dart';
import '../providers/standing_provider.dart';
import '../screens/match_detail_screen.dart';

/// Pins the soonest confirmed game above the feed with a live countdown. Hides
/// itself while the list loads, on error, when nothing is booked, and once
/// kickoff has passed.
class NextGameBanner extends ConsumerStatefulWidget {
  const NextGameBanner({super.key});

  @override
  ConsumerState<NextGameBanner> createState() => _NextGameBannerState();
}

class _NextGameBannerState extends ConsumerState<NextGameBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _open(String matchId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: matchId)),
    );
    if (!mounted) return;
    // The match page can change the roster, the score, or the field slots.
    ref.invalidate(myUpcomingMatchesProvider);
    ref.invalidate(matchFeedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(myUpcomingMatchesProvider).asData?.value;
    if (upcoming == null || upcoming.isEmpty) return const SizedBox.shrink();

    final match = upcoming.first;
    final status = KickoffStatus.at(
      match.startsAt,
      now: ref.watch(clockProvider)(),
    );
    if (status.phase == KickoffPhase.started) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = status.isLateCancelWindow ? scheme.error : scheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(match.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.sports_soccer,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEXT GAME',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            match.pitchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            dayTimeLabel(match.startsAt, match.endsAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.chipLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
                if (status.isLateCancelWindow)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 50, right: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: scheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Kickoff is under 3 hours away — leaving now '
                            'costs 25 points.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
