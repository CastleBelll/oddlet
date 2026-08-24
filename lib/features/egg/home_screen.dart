import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'egg_view.dart';
import 'shake_detector.dart';

/// Main screen of the app: the egg, and as little else as possible.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.shakeDetector});

  /// Injectable so tests and tools can drive the egg without real hardware.
  final ShakeDetector? shakeDetector;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _eggHeightRatio = 0.42;
  static const _maxEggHeight = 320.0;

  late final ShakeDetector _shakeDetector;

  @override
  void initState() {
    super.initState();
    _shakeDetector = widget.shakeDetector ?? ShakeDetector();
    _shakeDetector.start();
  }

  @override
  void dispose() {
    _shakeDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    child: EggView(
                      height: eggHeight,
                      shakes: _shakeDetector.shakes,
                    ),
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

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Text(
      'ODDLET',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: scheme.onSurfaceVariant,
        letterSpacing: 6,
      ),
    );
  }
}
