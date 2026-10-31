import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/pitchside_logo.dart';
import 'auth/auth_gate.dart';

/// The branded wait between the native launch window and the app's first
/// screen. The native splash cannot animate, so this continues the same green
/// canvas and gives the mark motion and a loading cue while the session
/// restores.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _pulse;

  late final Animation<double> _fade;
  late final Animation<Offset> _rise;
  late final Animation<double> _logoScale;
  late final Animation<double> _halo;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _rise = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _logoScale = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack));
    _halo = Tween<double>(
      begin: 0.9,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: AppColors.pitchGreen,
        body: Center(
          child: SlideTransition(
            position: _rise,
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _logoScale,
                    child: SizedBox(
                      width: 176,
                      height: 176,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ScaleTransition(
                            scale: _halo,
                            child: Container(
                              width: 168,
                              height: 168,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 108,
                            height: 108,
                            child: CustomPaint(
                              painter: PitchsideMarkPainter(scale: 0.92),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'PITCHSIDE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ADDIS ABABA',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 42),
                  SizedBox(
                    width: 128,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: AppColors.floodlight,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Holds the splash for a beat so the animation is seen, then hands the app to
/// [AuthGate] once the session state has resolved.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({
    super.key,
    this.minimumSplash = const Duration(milliseconds: 1000),
  });

  final Duration minimumSplash;

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  Timer? _timer;
  bool _minimumElapsed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.minimumSplash, () {
      if (mounted) setState(() => _minimumElapsed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(signedInProvider);
    final ready = _minimumElapsed && !signedIn.isLoading;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      child: ready ? const AuthGate() : const SplashScreen(),
    );
  }
}
