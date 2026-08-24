import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'egg_view.dart';

/// Main screen of the app: the egg, and as little else as possible.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _eggHeightRatio = 0.42;
  static const _maxEggHeight = 320.0;

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
                Expanded(child: Center(child: EggView(height: eggHeight))),
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
