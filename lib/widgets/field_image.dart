import 'package:flutter/material.dart';

import '../core/theme/field_art.dart';
import '../models/pitch.dart';

/// Venue photo with a bundled fallback, so a broken or missing URL still shows
/// grass instead of a grey box.
class FieldImage extends StatelessWidget {
  const FieldImage({super.key, required this.pitch, this.fit = BoxFit.cover});

  final Pitch pitch;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(FieldArt.forPitch(pitch.id), fit: fit);
    final url = pitch.imageUrl;
    if (url == null || url.isEmpty) return fallback;

    return Image.network(url, fit: fit, errorBuilder: (_, _, _) => fallback);
  }
}
