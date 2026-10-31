import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants/addis_sub_cities.dart';
import '../core/format/money.dart';
import '../core/time/addis_time.dart';
import '../models/organization.dart';
import '../models/pitch.dart';
import '../models/pitch_slot.dart';
import '../providers/create_match_provider.dart';
import '../providers/fields_provider.dart';
import '../providers/organizations_provider.dart';

class CreateMatchScreen extends ConsumerStatefulWidget {
  const CreateMatchScreen({
    super.key,
    this.initialPitch,
    this.initialStartsAt,
    this.initialDurationMinutes,
    this.organization,
  });

  /// Set when the organizer starts from a venue page.
  final Pitch? initialPitch;

  /// Set when the organizer picked a block on the venue's day grid.
  final DateTime? initialStartsAt;
  final int? initialDurationMinutes;

  /// Set when a club manager hosts on behalf of their company or team.
  final Organization? organization;

  @override
  ConsumerState<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends ConsumerState<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  /// The Addis calendar day the organizer is creating on.
  late DateTime _day;
  PitchSlot? _slot;
  Pitch? _pitch;
  int _teamSize = 5;
  int _durationMinutes = 60;
  bool _submitting = false;
  String? _error;

  /// Club mode: a game inside the club, or a challenge against another club.
  bool _challenge = false;
  String? _opponentId;

  /// True when the organizer arrived from a block on the venue's day grid.
  bool get _fromSlot =>
      widget.initialStartsAt != null && widget.initialPitch != null;

  /// A match is only ever booked into a field's own block, so its kickoff is
  /// always a time the field page sells.
  int get _blockMinutes => (_pitch?.blockHours ?? 2) * 60;

  /// Durations that finish inside the block the match was booked into.
  List<int> get _durationOptions {
    final cap = math.min(_blockMinutes, 180);
    return [60, 90, 120, 180].where((minutes) => minutes <= cap).toList();
  }

  /// What the organizer collects if every spot sells.
  String? get _priceHint {
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) return null;
    final players = _teamSize * 2;
    return '$players players × ${etb(price)} ETB = '
        '${etb(price * players)} ETB';
  }

  @override
  void initState() {
    super.initState();
    _pitch = widget.initialPitch;
    final startsAt = widget.initialStartsAt;
    if (startsAt != null) {
      _day = addisDate(startsAt);
      _durationMinutes = widget.initialDurationMinutes ?? _blockMinutes;
      _slot = PitchSlot(
        start: startsAt,
        end: startsAt.add(Duration(minutes: _durationMinutes)),
        isBooked: false,
      );
    } else {
      _day = addisToday().add(const Duration(days: 1));
    }
    _updateDateLabel();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateDateLabel() {
    _dateController.text = DateFormat('EEE, d MMM yyyy').format(_day);
  }

  Future<void> _pickDate() async {
    final today = addisToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _day = DateTime.utc(picked.year, picked.month, picked.day);
      _slot = null;
      _updateDateLabel();
    });
  }

  void _selectSlot(PitchSlot slot) {
    setState(() {
      _slot = slot;
      _durationMinutes = math.min(slot.lengthMinutes, 180);
    });
  }

  String? _validatePrice(String? value) {
    final price = double.tryParse(value?.trim() ?? '');
    if (price == null) return 'Enter a valid amount.';
    if (price < 0) return 'Price cannot be negative.';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final slot = _slot;
    if (slot == null) {
      setState(() => _error = 'Pick a free block at this field.');
      return;
    }
    if (!slot.start.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a kickoff time in the future.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final notes = _notesController.text.trim();
    try {
      await ref
          .read(createMatchControllerProvider.notifier)
          .create(
            pitchId: _pitch!.id,
            teamSize: _teamSize,
            startsAt: slot.start,
            durationMinutes: _durationMinutes,
            pricePerPlayer: double.parse(_priceController.text.trim()),
            notes: notes.isEmpty ? null : notes,
            organizationId: widget.organization?.id,
            opponentOrganizationId: _challenge ? _opponentId : null,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = createMatchErrorMessage(error);
        });
      }
    }
  }

  /// Clubs to challenge. Listing every club keeps the picker discoverable; the
  /// host's own club is not an option.
  Widget _buildOpponentPicker() {
    final theme = Theme.of(context);
    final host = widget.organization!;
    final directory = ref.watch(organizationsDirectoryProvider);

    return directory.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Row(
        children: [
          const Expanded(child: Text('Could not load the club list.')),
          TextButton(
            onPressed: () => ref.invalidate(organizationsDirectoryProvider),
            child: const Text('Try again'),
          ),
        ],
      ),
      data: (organizations) {
        final opponents = organizations
            .where((organization) => organization.id != host.id)
            .toList();
        if (opponents.isEmpty) {
          return Text(
            'No other club is on Pitchside yet. Host a game within your club '
            'for now.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: opponents.any((club) => club.id == _opponentId)
              ? _opponentId
              : null,
          isExpanded: true,
          validator: (_) => _challenge && _opponentId == null
              ? 'Choose the opponent club.'
              : null,
          decoration: const InputDecoration(
            labelText: 'Opponent club',
            border: OutlineInputBorder(),
            helperText: 'Their managers accept the invite, then their players can join.',
            helperMaxLines: 2,
          ),
          items: opponents
              .map(
                (organization) => DropdownMenuItem(
                  value: organization.id,
                  child: Text(
                    organization.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _opponentId = value),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pitches = ref.watch(pitchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.organization == null ? 'Create a match' : 'Host a club match',
        ),
      ),
      body: SafeArea(
        child: pitches.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load pitches'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(pitchesProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Center(child: Text('No active pitches available.'));
            }
            return _buildForm(items);
          },
        ),
      ),
    );
  }

  Widget _buildForm(List<Pitch> pitches) {
    final theme = Theme.of(context);
    // A venue opened from the directory may have gone inactive since the list
    // was fetched; the dropdown then starts empty instead of asserting.
    final selectedPitch = pitches.contains(_pitch) ? _pitch : null;
    final durations = _durationOptions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.organization != null) ...[
                  _ClubBanner(organization: widget.organization!),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Within club'),
                        icon: Icon(Icons.groups_2_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Vs another club'),
                        icon: Icon(Icons.shield_outlined),
                      ),
                    ],
                    selected: {_challenge},
                    onSelectionChanged: (selection) => setState(() {
                      _challenge = selection.first;
                      _opponentId = null;
                    }),
                  ),
                  if (_challenge) ...[
                    const SizedBox(height: 12),
                    _buildOpponentPicker(),
                  ],
                  const SizedBox(height: 20),
                ],
                if (_fromSlot && _slot != null)
                  _BookingSummary(
                    pitch: _pitch!,
                    startsAt: addisWall(_slot!.start),
                    endsAt: addisWall(_slot!.end),
                  )
                else ...[
                  DropdownButtonFormField<Pitch>(
                    initialValue: selectedPitch,
                    isExpanded: true,
                    validator: (value) =>
                        value == null ? 'Choose a pitch.' : null,
                    decoration: const InputDecoration(
                      labelText: 'Pitch',
                      border: OutlineInputBorder(),
                    ),
                    items: pitches
                        .map(
                          (pitch) => DropdownMenuItem(
                            value: pitch,
                            child: Text(
                              pitch.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _pitch = value;
                      _slot = null;
                      _durationMinutes = 60;
                    }),
                  ),
                  if (selectedPitch != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${selectedPitch.surface.replaceAll('_', ' ')} • '
                      '${etb(selectedPitch.pricePerHour)} ETB/hour • '
                      '${selectedPitch.blockHours}-hour blocks',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Kickoff · $eatLabel',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  _SlotChooser(
                    pitch: selectedPitch,
                    day: _day,
                    selected: _slot,
                    onSelected: _selectSlot,
                  ),
                ],
                const SizedBox(height: 20),
                Text('Format', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _teamSize > 5
                          ? () => setState(() => _teamSize--)
                          : null,
                      tooltip: 'Fewer players per side',
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${_teamSize}v$_teamSize',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${_teamSize * 2} players',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _teamSize < 11
                          ? () => setState(() => _teamSize++)
                          : null,
                      tooltip: 'More players per side',
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                Text(
                  'Any size from 5v5 to 11v11.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: durations.contains(_durationMinutes)
                      ? _durationMinutes
                      : durations.last,
                  decoration: InputDecoration(
                    labelText: 'Duration',
                    helperText: _fromSlot
                        ? 'Matches field block length ($eatLabel)'
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  items: durations
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes minutes'),
                        ),
                      )
                      .toList(),
                  onChanged: _fromSlot
                      ? null
                      : (value) => setState(
                          () => _durationMinutes = value ?? durations.last,
                        ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validatePrice,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Price per player (ETB)',
                    hintText: widget.organization == null
                        ? '0 for a free game'
                        : '0 if the club covers the field',
                    helperText: _priceHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _notesController,
                  maxLength: 500,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Bring a light and dark shirt',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sports_soccer),
                  label: Text(_submitting ? 'Creating match…' : 'Create match'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The field's free blocks for the chosen day, so the kickoff a match is
/// created with is exactly a block the field page shows as free.
class _SlotChooser extends ConsumerWidget {
  const _SlotChooser({
    required this.pitch,
    required this.day,
    required this.selected,
    required this.onSelected,
  });

  final Pitch? pitch;
  final DateTime day;
  final PitchSlot? selected;
  final ValueChanged<PitchSlot> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentPitch = pitch;
    if (currentPitch == null) {
      return Text(
        'Pick a field to see the blocks it sells.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final query = (pitchId: currentPitch.id, day: day);
    final slots = ref.watch(pitchSlotsProvider(query));

    return slots.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => Row(
        children: [
          Expanded(
            child: Text(
              'Could not load the blocks for this day.',
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
        final free = items.where((slot) => slot.isAvailable).toList();
        if (free.isEmpty) {
          return Text(
            'Every block on this day is booked or has already started.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in free)
              ChoiceChip(
                selected: selected?.start == slot.start,
                showCheckmark: false,
                onSelected: (_) => onSelected(slot),
                label: Text(
                  '${DateFormat.Hm().format(addisWall(slot.start))} – '
                  '${DateFormat.Hm().format(addisWall(slot.end))}',
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The block the organizer picked on the venue page, restated at the top of the
/// form so the date, time and field cost stay visible while they fill it in.
class _BookingSummary extends StatelessWidget {
  const _BookingSummary({
    required this.pitch,
    required this.startsAt,
    required this.endsAt,
  });

  final Pitch pitch;

  /// Already Addis wall-clock time.
  final DateTime startsAt;
  final DateTime endsAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final location = [
      subCityNameFor(pitch.subCityId),
      if (pitch.woreda?.isNotEmpty ?? false) pitch.woreda!,
    ].join(' · ');
    final timeFormat = DateFormat('HH:mm');

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
              Icon(Icons.stadium_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pitch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              location,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Fact(
                  icon: Icons.calendar_today_outlined,
                  label: DateFormat('EEE, d MMM').format(startsAt),
                ),
                _Fact(
                  icon: Icons.schedule_outlined,
                  label:
                      '${timeFormat.format(startsAt)} – ${timeFormat.format(endsAt)} $eatLabel',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              '${pitch.blockHours}-hour block at the field in $eatLabel (UTC+3) · '
              '${etb(pitch.blockPrice)} ETB',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Names the club the game belongs to, so the manager never has to guess
/// whether they are creating a public pickup or a club match.
class _ClubBanner extends StatelessWidget {
  const _ClubBanner({required this.organization});

  final Organization organization;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primary,
            child: Text(
              organization.initials,
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hosting for',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  organization.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
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
