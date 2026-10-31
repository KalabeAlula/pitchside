import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// The Pitchside badge: a bold P and a ball on pitch green. Drawn rather than
/// rasterised so it stays sharp from the launcher icon down to the sign-in
/// header. [PitchsideMarkPainter] draws the mark alone for platform artwork.
class PitchsideLogo extends StatelessWidget {
  const PitchsideLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.pitchGreen,
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: CustomPaint(painter: const PitchsideMarkPainter()),
      ),
    );
  }
}

/// The white P and amber ball, centred in a square canvas with a transparent
/// background. Coordinates are normalised to 0–1 so it scales without math.
class PitchsideMarkPainter extends CustomPainter {
  const PitchsideMarkPainter({this.scale = 1});

  /// Shrinks the mark around the centre, leaving breathing room in the icon's
  /// safe zone.
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(side * scale);
    canvas.translate(-0.5, -0.5);

    final white = Paint()
      ..color = Colors.white
      ..isAntiAlias = true;

    // Stem and bowl are unioned into one glyph so the join has no visible
    // seam where the two shapes meet.
    final stem = Path()
      ..addRRect(
        RRect.fromLTRBAndCorners(
          0.29,
          0.18,
          0.455,
          0.82,
          topLeft: const Radius.circular(0.075),
          bottomLeft: const Radius.circular(0.075),
          bottomRight: const Radius.circular(0.075),
        ),
      );

    // Bowl: a half ring growing right from the stem. The chord sits just
    // inside the stem.
    const bowlCenter = Offset(0.445, 0.395);
    final bowl = Path()
      ..addArc(
        Rect.fromCircle(center: bowlCenter, radius: 0.215),
        -math.pi / 2,
        math.pi,
      )
      ..arcTo(
        Rect.fromCircle(center: bowlCenter, radius: 0.085),
        math.pi / 2,
        -math.pi,
        false,
      )
      ..close();

    canvas.drawPath(Path.combine(PathOperation.union, stem, bowl), white);

    // Ball resting at the foot of the P.
    canvas.drawCircle(
      const Offset(0.60, 0.73),
      0.08,
      Paint()
        ..color = AppColors.floodlight
        ..isAntiAlias = true,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(PitchsideMarkPainter oldDelegate) =>
      oldDelegate.scale != scale;
}
