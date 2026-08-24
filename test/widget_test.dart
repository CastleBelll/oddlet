import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:oddlet/features/egg/egg_view.dart';
import 'package:oddlet/features/egg/home_screen.dart';
import 'package:oddlet/features/egg/shake_detector.dart';

/// A sample the detector should read as a shake of [magnitude] m/s^2 along x.
UserAccelerometerEvent sample(double magnitude, DateTime at) =>
    UserAccelerometerEvent(magnitude, 0, 0, at);

void main() {
  group('home screen', () {
    testWidgets('shows the wordmark and the egg', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(shakeDetector: ShakeDetector(samples: Stream.empty())),
        ),
      );

      expect(find.text('ODDLET'), findsOneWidget);
      expect(find.byType(EggView), findsOneWidget);
    });

    testWidgets('egg keeps animating without settling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(shakeDetector: ShakeDetector(samples: Stream.empty())),
        ),
      );

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

  group('ShakeDetector', () {
    final start = DateTime(2026, 1, 1);

    Future<List<Shake>> detect(List<UserAccelerometerEvent> samples) async {
      final source = StreamController<UserAccelerometerEvent>();
      final detector = ShakeDetector(samples: source.stream);
      final collected = detector.shakes.toList();

      detector.start();
      samples.forEach(source.add);
      // Let every sample reach the detector before tearing it down.
      await source.close();
      await detector.dispose();

      return collected;
    }

    test('ignores ordinary handling below the threshold', () async {
      final shakes = await detect([sample(5, start)]);

      expect(shakes, isEmpty);
    });

    test('reports a shake past the threshold', () async {
      final shakes = await detect([sample(20, start)]);

      expect(shakes, hasLength(1));
      expect(shakes.single.strength, greaterThan(1.0));
    });

    test('reports one event for a single physical shake', () async {
      // A real shake spans many samples over a few tens of milliseconds.
      final shakes = await detect([
        sample(20, start),
        sample(25, start.add(const Duration(milliseconds: 40))),
        sample(18, start.add(const Duration(milliseconds: 90))),
      ]);

      expect(shakes, hasLength(1));
    });

    test('reports the next shake once the cooldown has passed', () async {
      final shakes = await detect([
        sample(20, start),
        sample(20, start.add(const Duration(milliseconds: 400))),
      ]);

      expect(shakes, hasLength(2));
    });

    test('caps strength so a violent shake is not unbounded', () async {
      final shakes = await detect([sample(500, start)]);

      expect(shakes.single.strength, lessThanOrEqualTo(30.0 / 12.0));
    });

    test('takes direction from the sign of the sideways movement', () async {
      final shakes = await detect([
        sample(-20, start),
        sample(20, start.add(const Duration(milliseconds: 400))),
      ]);

      expect(shakes.map((shake) => shake.direction), [-1.0, 1.0]);
    });
  });
}
