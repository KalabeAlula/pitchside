import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/field_art.dart';
import '../models/pitch.dart';
import '../providers/auth_provider.dart';
import '../providers/fields_provider.dart';
import '../providers/match_feed_provider.dart';
import '../providers/sub_cities_provider.dart';
import '../widgets/field_card.dart';
import 'pitch_detail_screen.dart';

/// The field directory: the landing surface of the app. Photos lead, filters
/// narrow, and every tile opens the venue.
class FieldsScreen extends ConsumerStatefulWidget {
  const FieldsScreen({super.key});

  @override
  ConsumerState<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends ConsumerState<FieldsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(fieldSearchProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(fieldSearchProvider.notifier).update(value);
    });
    setState(() {});
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(fieldSearchProvider.notifier).update('');
    setState(() {});
  }

  Future<void> _openPitch(Pitch pitch) async {
    final messenger = ScaffoldMessenger.of(context);
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PitchDetailScreen(pitch: pitch)),
    );
    if (created == true) {
      ref.invalidate(matchFeedProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Match created. You are on Team A.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = ref.watch(fieldsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(fieldsProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _DirectoryHero()),
            SliverToBoxAdapter(
              child: _FilterPanel(
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                onClearSearch: _clearSearch,
              ),
            ),
            SliverToBoxAdapter(
              child: _ResultHeader(count: fields.value?.length),
            ),
            ..._buildBody(fields),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(AsyncValue<List<Pitch>> fields) {
    return fields.when(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
      error: (error, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: _DirectoryMessage(
              icon: Icons.cloud_off,
              title: 'Could not load fields',
              detail: '$error',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(fieldsProvider),
            ),
          ),
        ),
      ],
      data: (pitches) {
        if (pitches.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: _DirectoryMessage(
                  icon: Icons.sports_soccer,
                  title: 'No fields match',
                  detail: 'Try another sub-city, or clear the search.',
                  actionLabel: 'Clear filters',
                  onAction: () {
                    _clearSearch();
                    ref.read(fieldSubCityProvider.notifier).select(null);
                  },
                ),
              ),
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: pitches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final pitch = pitches[index];
                return FieldCard(
                  key: ValueKey(pitch.id),
                  pitch: pitch,
                  onTap: () => _openPitch(pitch),
                );
              },
            ),
          ),
        ];
      },
    );
  }
}

class _DirectoryHero extends ConsumerWidget {
  const _DirectoryHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 268,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(FieldArt.hero, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.42, 1],
                colors: [
                  Color(0xB3000000),
                  Color(0x40000000),
                  Color(0xE6000000),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.sports_soccer,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PITCHSIDE',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                        icon: const Icon(Icons.logout, color: Colors.white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const _HeroBadge(label: 'ADDIS ABABA'),
                  const SizedBox(height: 10),
                  Text(
                    'Find your field',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.02,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Turf and community pitches by the hour. Pick a field, '
                    'open a game.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _FilterPanel extends ConsumerWidget {
  const _FilterPanel({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subCities = ref.watch(subCitiesProvider).value ?? const [];
    final selected = ref.watch(fieldSubCityProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          children: [
            DropdownButtonFormField<String?>(
              initialValue: selected,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, size: 20),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                labelText: 'Sub-city',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All subcities'),
                ),
                ...subCities.map(
                  (city) => DropdownMenuItem(
                    value: city.id,
                    child: Text(city.nameEn),
                  ),
                ),
              ],
              onChanged: (value) =>
                  ref.read(fieldSubCityProvider.notifier).select(value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search fields...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: onClearSearch,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Row(
        children: [
          Text(
            'FOOTBALL FIELDS',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const Spacer(),
          if (count != null)
            Text(
              '$count ${count == 1 ? 'field' : 'fields'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _DirectoryMessage extends StatelessWidget {
  const _DirectoryMessage({
    required this.icon,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}
