import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daily_egg_controller.dart';
import 'egg_appearance.dart';
import 'egg_view.dart';
import 'hatch_sequence.dart';
import 'shake_detector.dart';

/// Main screen of the app: the egg, and as little else as possible.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.shakeDetector});

  /// Injectable so tests and tools can drive the egg without real hardware.
  final ShakeDetector? shakeDetector;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _eggHeightRatio = 0.42;
  static const _maxEggHeight = 320.0;

  late final ShakeDetector _shakeDetector;
  late final AppLifecycleListener _lifecycle;
  late final AnimationController _hatch;
  StreamSubscription<Shake>? _shakeCounter;
  HatchStage? _lastStage;

  @override
  void initState() {
    super.initState();

    _shakeDetector = widget.shakeDetector ?? ShakeDetector();
    _shakeDetector.start();
    _shakeCounter = _shakeDetector.shakes.listen(
      (_) => ref.read(dailyEggControllerProvider.notifier).recordShake(),
    );

    _hatch = AnimationController(vsync: this, duration: hatchDuration)
      ..addListener(_onHatchTick)
      ..addStatusListener(_onHatchStatus);

    // Counts are batched before they reach the disk, so write them out before
    // the app can be killed in the background.
    _lifecycle = AppLifecycleListener(
      onPause: () =>
          unawaited(ref.read(dailyEggControllerProvider.notifier).flush()),
    );
  }

  /// Each stage of the shell giving way gets its own knock in the hand.
  void _onHatchTick() {
    final stage = hatchStageAt(_hatch.value);
    if (stage != _lastStage) {
      _lastStage = stage;
      switch (stage) {
        case HatchStage.cracking:
          HapticFeedback.mediumImpact();
        case HatchStage.breaking:
          HapticFeedback.heavyImpact();
        case HatchStage.trembling:
        case HatchStage.blackout:
        case HatchStage.done:
          break;
      }
    }
    setState(() {});
  }

  void _onHatchStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    // TODO(TASK-008): hand the result over to the reveal instead of putting
    // the egg back. Resetting keeps the sequence replayable while it is tuned.
    _lastStage = null;
    _hatch.reset();
  }

  void _beginHatch() {
    if (_hatch.isAnimating) {
      return;
    }
    HapticFeedback.selectionClick();
    _hatch.forward(from: 0);
  }

  @override
  void dispose() {
    _hatch.dispose();
    _lifecycle.dispose();
    _shakeCounter?.cancel();
    _shakeDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final egg = ref.watch(dailyEggControllerProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final eggHeight = math.min(
              constraints.maxHeight * _eggHeightRatio,
              _maxEggHeight,
            );

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: _Wordmark(),
                ),
                Expanded(
                  child: Center(
                    child: egg.hasValue
                        ? _Egg(
                            height: eggHeight,
                            day: egg.requireValue.day,
                            shakes: _shakeDetector.shakes,
                            hatchProgress: _hatch.isAnimating
                                ? _hatch.value
                                : null,
                            onHatchRequested: _beginHatch,
                          )
                        : SizedBox(height: eggHeight),
                  ),
                ),
              ],
            );
              },
            ),
          ),
          if (_hatch.isAnimating) _HatchOverlay(progress: _hatch.value),
        ],
      ),
    );
  }
}

/// The flash of the shell giving way, and the dark the reveal opens out of.
class _HatchOverlay extends StatelessWidget {
  const _HatchOverlay({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: blackoutAt(progress),
            child: const ColoredBox(color: Colors.black),
          ),
          Opacity(
            opacity: flashAt(progress),
            child: const ColoredBox(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Egg extends ConsumerWidget {
  const _Egg({
    required this.height,
    required this.day,
    required this.shakes,
    required this.hatchProgress,
    required this.onHatchRequested,
  });

  final double height;
  final DateTime day;
  final Stream<Shake> shakes;
  final double? hatchProgress;
  final VoidCallback onHatchRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EggView(
      height: height,
      // Derived from the egg's own day, so crossing midnight with the app open
      // changes the shell along with the egg.
      appearance: EggAppearance.forDay(day),
      shakes: shakes,
      onTouch: ref.read(dailyEggControllerProvider.notifier).recordTouch,
      hatchProgress: hatchProgress,
      onHatchRequested: onHatchRequested,
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Text(
      // The brand mark, not copy: it reads the same in every language.
      'ODDLET',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: scheme.onSurfaceVariant,
        letterSpacing: 6,
      ),
    );
  }
}
