import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oddlet/features/egg/egg_view.dart';
import 'package:oddlet/features/egg/home_screen.dart';

void main() {
  group('home screen', () {
    testWidgets('shows the wordmark and the egg', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      expect(find.text('ODDLET'), findsOneWidget);
      expect(find.byType(EggView), findsOneWidget);
    });

    testWidgets('egg keeps animating without settling', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      // A repeating idle animation never settles; pumpAndSettle would time out.
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.hasRunningAnimations, isTrue);
    });
  });

  group('pokeAmplitude', () {
    test('is fully squashed at the moment of contact', () {
      expect(pokeAmplitude(0), 1.0);
    });

    test('never overshoots the contact amplitude', () {
      for (var step = 0; step <= 120; step++) {
        final amplitude = pokeAmplitude(step / 100);

        expect(amplitude.abs(), lessThanOrEqualTo(1.0));
      }
    });

    test('rings back and forth before settling', () {
      // A pure decay would never go negative; the shell must rebound.
      final samples = [
        for (var step = 0; step <= 60; step++) pokeAmplitude(step / 100),
      ];

      expect(samples.any((amplitude) => amplitude < -0.05), isTrue);
    });

    test('has rung out well before the poke window closes', () {
      expect(pokeAmplitude(1.2).abs(), lessThan(0.01));
    });

    test('ignores time before contact', () {
      expect(pokeAmplitude(-1), 0.0);
    });
  });
}
