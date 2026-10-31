import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_model.dart';
import '../providers/auth_provider.dart';
import '../providers/match_feed_provider.dart';
import '../providers/sub_cities_provider.dart';
import '../widgets/join_match_sheet.dart';
import '../widgets/match_card.dart';
import 'match_detail_screen.dart';
import 'my_standing_screen.dart';

class MatchFeedScreen extends ConsumerWidget {
  const MatchFeedScreen({super.key});

  Future<void> _openMatch(
    BuildContext context,
    WidgetRef ref,
    MatchOverview match,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MatchDetailScreen(matchId: match.id, initialMatch: match),
      ),
    );
    // Joining, leaving or cancelling inside the page changes the card.
    ref.invalidate(matchFeedProvider);
  }

  Future<void> _onJoinPressed(BuildContext context, MatchOverview match) async {
    final messenger = ScaffoldMessenger.of(context);

    // Client-side guard only; join_match() re-checks capacity under a row lock.
    if (match.isFull) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${match.pitchName} is full — open it to join the waiting list.',
          ),
        ),
      );
      return;
    }

    final status = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => JoinMatchSheet(match: match),
    );

    if (status == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          status == 'waitlisted'
              ? "You're on the waiting list. We'll move you in if someone drops out."
              : 'Spot confirmed. See you on the pitch!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(matchFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pickup games',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Addis Ababa',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.verified_user_outlined),
            tooltip: 'My standing',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MyStandingScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(matchFeedProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          const _SubCityFilterBar(),
          Expanded(
            child: feed.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _FeedError(
                error: error,
                onRetry: () => ref.invalidate(matchFeedProvider),
              ),
              data: (matches) => RefreshIndicator(
                onRefresh: () => ref.refresh(matchFeedProvider.future),
                child: matches.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(48),
                            child: _EmptyFeed(),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: matches.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final match = matches[index];
                          return MatchCard(
                            key: ValueKey(match.id),
                            match: match,
                            onJoin: () => _onJoinPressed(context, match),
                            onOpen: () => _openMatch(context, ref, match),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubCityFilterBar extends ConsumerWidget {
  const _SubCityFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subCities = ref.watch(subCitiesProvider);
    final selected = ref.watch(selectedSubCityProvider);
    final notifier = ref.read(selectedSubCityProvider.notifier);

    return SizedBox(
      height: 60,
      child: subCities.when(
        loading: () => const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, _) => const Center(child: Text('Filters unavailable')),
        data: (cities) => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: cities.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return ChoiceChip(
                label: const Text('All of Addis'),
                selected: selected == null,
                onSelected: (_) => notifier.select(null),
              );
            }
            final city = cities[index - 1];
            return ChoiceChip(
              label: Text(city.nameEn),
              selected: selected == city.id,
              onSelected: (_) =>
                  notifier.select(selected == city.id ? null : city.id),
            );
          },
        ),
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load games',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
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

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.sports_soccer,
          size: 44,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'No upcoming games here',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Try another sub-city, or check back later.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
