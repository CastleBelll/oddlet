import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daily_egg_controller.dart';
import 'egg_appearance.dart';
import 'egg_view.dart';
import 'shake_detector.dart';

/// Main screen of the app: the egg, and as little else as possible.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.shakeDetector});

  /// Injectable so tests and tools can drive the egg without real hardware.
  final ShakeDetector? shakeDetector;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _eggHeightRatio = 0.42;
  static const _maxEggHeight = 320.0;

  late final ShakeDetector _shakeDetector;
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<Shake>? _shakeCounter;

  @override
  void initState() {
    super.initState();

    _shakeDetector = widget.shakeDetector ?? ShakeDetector();
    _shakeDetector.start();
    _shakeCounter = _shakeDetector.shakes.listen(
      (_) => ref.read(dailyEggControllerProvider.notifier).recordShake(),
    );

    // Counts are batched before they reach the disk, so write them out before
    // the app can be killed in the background.
    _lifecycle = AppLifecycleListener(
      onPause: () =>
          unawaited(ref.read(dailyEggControllerProvider.notifier).flush()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _shakeCounter?.cancel();
    _shakeDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final egg = ref.watch(dailyEggControllerProvider);

    return Scaffold(
      body: SafeArea(
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
                        ? _Egg(height: eggHeight, day: egg.requireValue.day,
                            shakes: _shakeDetector.shakes)
                        : SizedBox(height: eggHeight),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Egg extends ConsumerWidget {
  const _Egg({required this.height, required this.day, required this.shakes});

  final double height;
  final DateTime day;
  final Stream<Shake> shakes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EggView(
      height: height,
      // Derived from the egg's own day, so crossing midnight with the app open
      // changes the shell along with the egg.
      appearance: EggAppearance.forDay(day),
      shakes: shakes,
      onTouch: ref.read(dailyEggControllerProvider.notifier).recordTouch,
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
