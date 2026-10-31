import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants/addis_sub_cities.dart';
import '../core/format/money.dart';
import '../core/location/google_maps.dart';
import '../core/theme/app_colors.dart';
import '../core/time/addis_time.dart';
import '../models/pitch.dart';
import '../models/pitch_review.dart';
import '../models/pitch_slot.dart';
import '../providers/fields_provider.dart';
import '../widgets/field_image.dart';
import '../widgets/rating_stars.dart';
import 'create_match_screen.dart';
import 'pin_picker_screen.dart';

/// Venue page: photo, the day's slots, the facts that decide a booking,
/// house rules, and the reviews left by players who have already played here.
class PitchDetailScreen extends ConsumerStatefulWidget {
  const PitchDetailScreen({super.key, required this.pitch});

  final Pitch pitch;

  @override
  ConsumerState<PitchDetailScreen> createState() => _PitchDetailScreenState();
}

class _PitchDetailScreenState extends ConsumerState<PitchDetailScreen> {
  late DateTime _day;
  PitchSlot? _slot;

  /// Set once an operator saves a pin here, so the page reflects the new
  /// coordinates without leaving the screen.
  Pitch? _savedPitch;

  Pitch get _pitch => _savedPitch ?? widget.pitch;

  @override
  void initState() {
    super.initState();
    _day = _today();
  }

  static DateTime _today() => addisToday();

  void _selectDay(DateTime day) {
    setState(() {
      _day = day;
      _slot = null;
    });
  }

  Future<void> _createMatch() async {
    final slot = _slot;
    if (slot == null) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateMatchScreen(
          initialPitch: _pitch,
          initialStartsAt: slot.start,
          initialDurationMinutes: _pitch.blockHours * 60,
        ),
      ),
    );
    if (!mounted) return;
    if (created == true) {
      // The block just sold; the next visit to this day must refetch.
      ref.invalidate(pitchSlotsProvider);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _editPin() async {
    final updated = await Navigator.of(context).push<Pitch>(
      MaterialPageRoute(builder: (_) => PinPickerScreen(pitch: _pitch)),
    );
    if (!mounted || updated == null) return;
    setState(() => _savedPitch = updated);
    // The directory and map views read their own copies of the pin.
    ref.invalidate(fieldsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exact pin saved for this field.')),
    );
  }

  Future<void> _openDirections() async {
    final uri = googleMapsDirectionsUri(
      name: _pitch.name,
      address: _pitch.address,
      subCityName: subCityNameFor(_pitch.subCityId),
      latitude: _pitch.latitude,
      longitude: _pitch.longitude,
    );
    final opened = await openGoogleMaps(uri);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open Google Maps. Check your browser and try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOperator =
        ref.watch(isFieldOperatorProvider).asData?.value ?? false;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: AppColors.pitchGreen,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                end: 16,
                bottom: 14,
              ),
              title: Text(
                _pitch.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              background: _PitchHero(pitch: _pitch),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Pick a slot'),
                  const SizedBox(height: 10),
                  _SlotPicker(
                    pitch: _pitch,
                    day: _day,
                    selected: _slot,
                    onDay: _selectDay,
                    onSelect: (slot) => setState(() => _slot = slot),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('About this field'),
                  const SizedBox(height: 10),
                  Text(
                    _pitch.description ??
                        'A football venue in ${subCityNameFor(_pitch.subCityId)}. '
                            'Ask the operator about changing rooms and parking '
                            'before your first game.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  if (_pitch.amenities.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const _SectionTitle('Amenities'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final amenity in _pitch.amenities)
                          Chip(
                            label: Text(amenity),
                            avatar: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  const _SectionTitle('The basics'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Fact(
                          icon: Icons.grass,
                          label: 'Surface',
                          value: _pitch.surfaceLabel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Fact(
                          icon: Icons.payments_outlined,
                          label: 'Per hour',
                          value: '${etb(_pitch.pricePerHour)} ETB',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Fact(
                          icon: Icons.lightbulb_outline,
                          label: 'Floodlights',
                          value: switch (_pitch.hasFloodlights) {
                            true => 'Yes',
                            false => 'No',
                            null => 'Not listed',
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Fact(
                          icon: Icons.location_city_outlined,
                          label: 'Sub-city',
                          value: subCityNameFor(_pitch.subCityId),
                        ),
                      ),
                    ],
                  ),
                  if (_pitch.houseRules.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const _SectionTitle('House rules'),
                    const SizedBox(height: 10),
                    for (final rule in _pitch.houseRules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                rule,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 18),
                  const _SectionTitle('Location'),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.place_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pitch.address ?? 'Address on request',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        subCityNameFor(_pitch.subCityId),
                                        if (_pitch.woreda != null)
                                          _pitch.woreda!,
                                        if (_pitch.hasPin) ...[
                                          '${_pitch.latitude!.toStringAsFixed(4)}, '
                                              '${_pitch.longitude!.toStringAsFixed(4)}',
                                          if (!_pitch.hasExactPin)
                                            'Approximate pin',
                                        ] else
                                          'Exact pin not published',
                                      ].join(' · '),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: _openDirections,
                              icon: const Icon(Icons.directions_outlined),
                              label: const Text('Get directions'),
                            ),
                          ),
                          if (!_pitch.hasPin) ...[
                            const SizedBox(height: 8),
                            Text(
                              'No exact pin yet — Maps searches by the name '
                              'and address above.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ] else if (!_pitch.hasExactPin) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Approximate pin — it marks the area, not the '
                              'exact gate. Confirm with the operator.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (isOperator) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _editPin,
                                icon: const Icon(
                                  Icons.add_location_alt_outlined,
                                ),
                                label: Text(
                                  _pitch.hasExactPin
                                      ? 'Move exact pin'
                                      : 'Set exact pin',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle('Reviews'),
                  const SizedBox(height: 10),
                  _Reviews(pitch: _pitch),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BookingBar(
        pitch: _pitch,
        slot: _slot,
        onCreate: _createMatch,
      ),
    );
  }
}

/// Three-day block grid. Booked and passed blocks stay visible but inert, so
/// the day reads like a timetable rather than a list that shifts under you.
class _SlotPicker extends ConsumerWidget {
  const _SlotPicker({
    required this.pitch,
    required this.day,
    required this.selected,
    required this.onDay,
    required this.onSelect,
  });

  final Pitch pitch;
  final DateTime day;
  final PitchSlot? selected;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<PitchSlot> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final query = (pitchId: pitch.id, day: day);
    final slots = ref.watch(pitchSlotsProvider(query));
    final today = addisToday();
    final days = [for (var i = 0; i < 3; i++) today.add(Duration(days: i))];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${pitch.blockHours}-hour blocks in $eatLabel (UTC+3) · '
                '${etb(pitch.blockPrice)} ETB each',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < days.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _DayChip(
                  day: days[i],
                  isSelected: DateUtils.isSameDay(day, days[i]),
                  onSelected: onDay,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        slots.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, _) => Row(
            children: [
              Expanded(
                child: Text(
                  'Could not load the slots for this day.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(pitchSlotsProvider(query)),
                child: const Text('Try again'),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return Text(
                'No slots published for this day.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.3,
              children: [
                for (final slot in items)
                  _SlotTile(
                    slot: slot,
                    isSelected: selected?.start == slot.start,
                    onTap: slot.isAvailable ? () => onSelect(slot) : null,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.isSelected,
    required this.onSelected,
  });

  final DateTime day;
  final bool isSelected;
  final ValueChanged<DateTime> onSelected;

  String get _label {
    final today = addisToday();
    final target = DateUtils.dateOnly(day);
    final offset = target.difference(today).inDays;
    if (offset == 0) return 'Today';
    if (offset == 1) return 'Tomorrow';
    return DateFormat('EEE d MMM').format(day);
  }

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: SizedBox(
        width: double.infinity,
        child: Text(_label, textAlign: TextAlign.center),
      ),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) => onSelected(day),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  final PitchSlot slot;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = addisWall(slot.start);
    final label =
        '${DateFormat.Hm().format(start)} – '
        '${DateFormat.Hm().format(addisWall(slot.end))}';

    final String status;
    if (slot.isBooked) {
      status = 'Booked';
    } else if (slot.isPast) {
      status = 'Passed';
    } else {
      status = isSelected ? 'Selected' : 'Free';
    }

    final Color background;
    final Color border;
    final Color foreground;
    if (slot.isAvailable) {
      background = isSelected ? scheme.primary : scheme.surface;
      border = isSelected ? scheme.primary : scheme.outlineVariant;
      foreground = isSelected ? scheme.onPrimary : scheme.onSurface;
    } else {
      background = scheme.surfaceContainerHighest.withValues(alpha: 0.55);
      border = scheme.outlineVariant.withValues(alpha: 0.5);
      foreground = scheme.onSurfaceVariant;
    }

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: slot.isAvailable
                      ? (isSelected ? scheme.onPrimary : scheme.primary)
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PitchHero extends StatelessWidget {
  const _PitchHero({required this.pitch});

  final Pitch pitch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = [
      subCityNameFor(pitch.subCityId),
      if (pitch.woreda != null) pitch.woreda!,
    ].join(', ');

    return Stack(
      fit: StackFit.expand,
      children: [
        FieldImage(pitch: pitch),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.3, 0.72, 1],
              colors: [
                Color(0xA6000000),
                Color(0x26000000),
                Color(0x40000000),
                Color(0xC4000000),
              ],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 60,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    label: 'FOOTBALL',
                    background: AppColors.accent,
                    foreground: Colors.white,
                    icon: Icons.sports_soccer,
                  ),
                  _Pill(
                    label: location.toUpperCase(),
                    background: Colors.white.withValues(alpha: 0.16),
                    foreground: Colors.white,
                    icon: Icons.place_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (pitch.hasPlayerReviews)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RatingStars(rating: pitch.ratingAvg!, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      '${pitch.ratingAvg!.toStringAsFixed(1)} · '
                      '${pitch.reviewCount} '
                      '${pitch.reviewCount == 1 ? 'review' : 'reviews'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              else if (pitch.directoryRating != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RatingStars(rating: pitch.directoryRating!, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      '${pitch.directoryRating!.toStringAsFixed(1)} · '
                      'city directory rating',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'New field · no reviews yet',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 3,
          width: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
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

class _Reviews extends ConsumerWidget {
  const _Reviews({required this.pitch});

  final Pitch pitch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviews = ref.watch(pitchReviewsProvider(pitch.id));

    return reviews.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => Text(
        'Reviews are unavailable right now.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Text(
            'No Pitchside reviews yet. Play a game here, then tell everyone '
            'how it was.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          );
        }
        return Column(
          children: [for (final review in items) _ReviewTile(review: review)],
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final PitchReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.reviewerName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('d MMM').format(addisWall(review.createdAt)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              RatingStars(rating: review.rating.toDouble()),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(review.comment!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  const _BookingBar({
    required this.pitch,
    required this.slot,
    required this.onCreate,
  });

  final Pitch pitch;
  final PitchSlot? slot;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = slot;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    selected == null ? 'STARTING FROM' : 'YOUR SLOT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      selected == null
                          ? '${etb(pitch.pricePerHour)} ETB / HR'
                          : '${DateFormat('EEE d MMM · HH:mm').format(addisWall(selected.start))}'
                                ' – ${DateFormat.Hm().format(addisWall(selected.end))} $eatLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (selected != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${etb(pitch.blockPrice)} ETB',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: selected == null ? null : onCreate,
                icon: const Icon(Icons.sports_soccer, size: 18),
                label: Text(
                  selected == null
                      ? 'Pick a slot above'
                      : 'Create match · ${DateFormat.Hm().format(addisWall(selected.start))}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
