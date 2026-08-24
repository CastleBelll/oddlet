import 'package:flutter_test/flutter_test.dart';

import 'package:oddlet/features/egg/hatch_sequence.dart';

/// Samples across the whole run, for properties that must hold throughout.
Iterable<double> everyMoment({int steps = 200}) sync* {
  for (var step = 0; step <= steps; step++) {
    yield step / steps;
  }
}

void main() {
  group('stages', () {
    test('run in order and end done', () {
      expect(hatchStageAt(0), HatchStage.trembling);
      expect(hatchStageAt(0.5), HatchStage.cracking);
      expect(hatchStageAt(0.85), HatchStage.breaking);
      expect(hatchStageAt(0.95), HatchStage.blackout);
      expect(hatchStageAt(1), HatchStage.done);
    });

    test('never go backwards', () {
      var previous = HatchStage.trembling;

      for (final t in everyMoment()) {
        final stage = hatchStageAt(t);

        expect(stage.index, greaterThanOrEqualTo(previous.index));
        previous = stage;
      }
    });
  });

  group('cracks', () {
    test('do not start until the shell has trembled', () {
      expect(crackProgressAt(0), 0);
      expect(crackProgressAt(0.2), 0);
    });

    test('are fully open once the shell breaks', () {
      expect(crackProgressAt(0.78), 1);
      expect(crackProgressAt(1), 1);
    });

    test('only ever spread further', () {
      var previous = 0.0;

      for (final t in everyMoment(steps: 500)) {
        final crack = crackProgressAt(t);

        expect(crack, greaterThanOrEqualTo(previous));
        expect(crack, inInclusiveRange(0, 1));
        previous = crack;
      }
    });

    test('give way in lurches rather than at a steady rate', () {
      // Sample the rate of spread across the cracking stage. A steady ramp
      // would show one rate; lurches show fast and slow patches.
      final rates = <double>[];
      for (var step = 0; step < 60; step++) {
        final from = 0.28 + (0.78 - 0.28) * step / 60;
        final to = 0.28 + (0.78 - 0.28) * (step + 1) / 60;
        rates.add(crackProgressAt(to) - crackProgressAt(from));
      }

      final fastest = rates.reduce((a, b) => a > b ? a : b);
      final slowest = rates.reduce((a, b) => a < b ? a : b);
      expect(fastest, greaterThan(slowest * 3));
    });
  });

  group('trembling', () {
    test('builds up rather than starting at full strength', () {
      expect(trembleAt(0), 0);
      expect(trembleAt(0.14), closeTo(0.5, 0.01));
      expect(trembleAt(0.28), 1);
    });

    test('stops once the shell is open', () {
      expect(trembleAt(0.9), 0);
      expect(trembleAt(1), 0);
    });

    test('stays within range throughout', () {
      for (final t in everyMoment()) {
        expect(trembleAt(t), inInclusiveRange(0, 1));
      }
    });
  });

  group('overlays', () {
    test('are absent while the shell is still whole', () {
      expect(flashAt(0.5), 0);
      expect(blackoutAt(0.5), 0);
    });

    test('flash peaks as the shell breaks, then clears', () {
      expect(flashAt(0.78), 0);
      expect(flashAt(0.90), 1);
      expect(flashAt(1), 0);
    });

    test('leave the screen dark at the end, ready for the reveal', () {
      expect(blackoutAt(1), 1);
      expect(flashAt(1), 0);
    });

    test('stay within range throughout', () {
      for (final t in everyMoment()) {
        expect(flashAt(t), inInclusiveRange(0, 1));
        expect(blackoutAt(t), inInclusiveRange(0, 1));
        expect(shellOpacityAt(t), inInclusiveRange(0, 1));
      }
    });
  });

  group('the shell', () {
    test('stays solid until it breaks, then goes', () {
      expect(shellOpacityAt(0), 1);
      expect(shellOpacityAt(0.78), 1);
      expect(shellOpacityAt(0.90), 0);
      expect(shellOpacityAt(1), 0);
    });

    test('is gone before the screen finishes going dark', () {
      // Otherwise the shell would be visible sitting on top of the blackout.
      expect(shellOpacityAt(0.95), 0);
      expect(blackoutAt(0.95), lessThan(1));
    });
  });
}
