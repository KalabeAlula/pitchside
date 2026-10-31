import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants/addis_sub_cities.dart';
import '../core/theme/app_colors.dart';
import '../models/pitch.dart';
import '../providers/service_provider.dart';

/// Basemap tiles for the pin map. Widget tests override this with a local
/// provider so the map never reaches the network.
final pinTileProviderProvider = Provider<TileProvider>(
  (ref) => NetworkTileProvider(),
);

/// Operator-only map for turning an area pin into the field's real gate. The
/// approximate pin is the starting point; tapping moves the marker, and saving
/// hands the coordinates to the database, which re-checks the operator role.
class PinPickerScreen extends ConsumerStatefulWidget {
  const PinPickerScreen({super.key, required this.pitch});

  final Pitch pitch;

  @override
  ConsumerState<PinPickerScreen> createState() => _PinPickerScreenState();
}

class _PinPickerScreenState extends ConsumerState<PinPickerScreen> {
  /// Meskel Square — where an unpinned field's map opens before it is placed.
  static const _cityCenter = LatLng(9.0108, 38.7613);

  LatLng? _pin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pitch = widget.pitch;
    if (pitch.latitude != null && pitch.longitude != null) {
      _pin = LatLng(pitch.latitude!, pitch.longitude!);
    }
  }

  void _place(TapPosition _, LatLng point) {
    setState(() => _pin = point);
  }

  Future<void> _save() async {
    final pin = _pin;
    if (pin == null || _saving) return;
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(pitchsideServiceProvider)
          .setPitchPin(
            pitchId: widget.pitch.id,
            latitude: pin.latitude,
            longitude: pin.longitude,
          );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_saveError(error))));
    }
  }

  static String _saveError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('outside addis ababa')) {
      return 'That spot is outside Addis Ababa.';
    }
    if (text.contains('only operators')) {
      return 'Your account cannot pin fields.';
    }
    return 'Could not save the pin. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pin = _pin;
    final tileProvider = ref.watch(pinTileProviderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exact pin')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.pitch.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    subCityNameFor(widget.pitch.subCityId),
                    if (widget.pitch.woreda != null) widget.pitch.woreda!,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  pin == null
                      ? 'Tap the map where the gate is.'
                      : 'Drag the map, then tap to move the pin. The marker '
                            'tip is the saved point.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: pin ?? _cityCenter,
                  initialZoom: pin == null ? 13 : 17,
                  minZoom: 11,
                  maxZoom: 19,
                  onTap: _place,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'et.pitchside.pitchside',
                    maxNativeZoom: 19,
                    tileProvider: tileProvider,
                  ),
                  if (pin != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: pin,
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on,
                            size: 44,
                            color: AppColors.accent,
                            shadows: [
                              Shadow(color: Color(0x66000000), blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    pin == null
                        ? 'No pin placed yet'
                        : '${pin.latitude.toStringAsFixed(6)}, '
                              '${pin.longitude.toStringAsFixed(6)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: pin == null || _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.pin_drop_outlined, size: 18),
                    label: const Text('Save exact pin'),
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
