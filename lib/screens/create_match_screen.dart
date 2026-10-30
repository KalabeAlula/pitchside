import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants/addis_sub_cities.dart';
import '../core/format/money.dart';
import '../core/time/addis_time.dart';
import '../models/pitch.dart';
import '../models/pitch_slot.dart';
import '../providers/create_match_provider.dart';
import '../providers/fields_provider.dart';

class CreateMatchScreen extends ConsumerStatefulWidget {
  const CreateMatchScreen({
    super.key,
    this.initialPitch,
    this.initialStartsAt,
    this.initialDurationMinutes,
  });

  /// Set when the organizer starts from a venue page.
  final Pitch? initialPitch;

  /// Set when the organizer picked a block on the venue's day grid.
  final DateTime? initialStartsAt;
  final int? initialDurationMinutes;

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

  @override
  Widget build(BuildContext context) {
    final pitches = ref.watch(pitchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create a match')),
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
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    border: OutlineInputBorder(),
                  ),
                  items: durations
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes minutes'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
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
                    hintText: '0 for a free game',
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
    final time = DateFormat.jm();

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
                  label: '${time.format(startsAt)} – ${time.format(endsAt)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              '${pitch.blockHours}-hour block at the field in $eatLabel · '
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
