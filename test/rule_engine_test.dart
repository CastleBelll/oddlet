import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:oddlet/features/creatures/creature_appearance.dart';
import 'package:oddlet/features/rules/creature.dart';
import 'package:oddlet/features/rules/rule_engine.dart';
import 'package:oddlet/features/rules/season_01.dart';

HatchContext context({int touches = 0, int shakes = 0, DateTime? hatchedAt}) =>
    HatchContext(
      touchCount: touches,
      shakeCount: shakes,
      hatchedAt: hatchedAt ?? DateTime(2026, 8, 24, 12),
    );

const fallback = Creature(id: 'fallback', rarity: Rarity.common);

void main() {
  group('HatchWindow', () {
    test('covers its own span and excludes the end', () {
      final window = HatchWindow.between(3, 4);

      expect(window.contains(DateTime(2026, 1, 1, 3)), isTrue);
      expect(window.contains(DateTime(2026, 1, 1, 3, 59)), isTrue);
      expect(window.contains(DateTime(2026, 1, 1, 4)), isFalse);
      expect(window.contains(DateTime(2026, 1, 1, 2, 59)), isFalse);
    });

    test('handles a window that runs past midnight', () {
      final window = HatchWindow.between(23, 2);

      expect(window.contains(DateTime(2026, 1, 1, 23, 30)), isTrue);
      expect(window.contains(DateTime(2026, 1, 1, 0, 30)), isTrue);
      expect(window.contains(DateTime(2026, 1, 1, 12)), isFalse);
    });
  });

  group('time of day is read where the user is', () {
    test('refuses an instant that is not in the user local time', () {
      // Server time arrives as UTC. Handing it straight to the rules would
      // make the small hours land at the same moment worldwide.
      expect(
        () => HatchContext(
          touchCount: 0,
          shakeCount: 0,
          hatchedAt: DateTime.utc(2026, 8, 24, 3, 30),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('depends on the clock face, not on which instant it is', () {
      final window = HatchWindow.between(2, 5);

      // Same wall-clock time on different dates and years: a user in any
      // country reads 3:30am off their own clock and gets the same answer.
      expect(window.contains(DateTime(2026, 1, 1, 3, 30)), isTrue);
      expect(window.contains(DateTime(2026, 6, 15, 3, 30)), isTrue);
      expect(window.contains(DateTime(2031, 12, 31, 3, 30)), isTrue);
    });

    test('stays reachable across a daylight saving jump', () {
      // Where clocks spring forward, 02:00 to 03:00 does not exist that day.
      // A window covering only that hour would be impossible for a whole
      // country, so the dawn windows are wider than the gap.
      for (final creature in season01Creatures) {
        final window = creature.conditions.hatchWindow;
        if (window == null) {
          continue;
        }

        final span = window.toMinute > window.fromMinute
            ? window.toMinute - window.fromMinute
            : Duration.minutesPerDay - window.fromMinute + window.toMinute;

        expect(
          span,
          greaterThan(Duration.minutesPerHour),
          reason:
              '${creature.id} has a window no wider than the hour daylight '
              'saving can remove',
        );
      }
    });
  });

  group('HatchConditions', () {
    test('with nothing set matches anything', () {
      expect(HatchConditions.always.isUnconditional, isTrue);
      expect(HatchConditions.always.matches(context()), isTrue);
    });

    test('needs every condition present to hold', () {
      const conditions = HatchConditions(minTouches: 10, minShakes: 5);

      expect(conditions.matches(context(touches: 10, shakes: 5)), isTrue);
      expect(conditions.matches(context(touches: 10, shakes: 4)), isFalse);
      expect(conditions.matches(context(touches: 9, shakes: 5)), isFalse);
    });

    test('treats a minimum as met exactly at the threshold', () {
      const conditions = HatchConditions(minTouches: 100);

      expect(conditions.matches(context(touches: 99)), isFalse);
      expect(conditions.matches(context(touches: 100)), isTrue);
    });
  });

  group('RuleEngine', () {
    test('refuses a set that cannot answer every egg', () {
      expect(() => RuleEngine([]), throwsArgumentError);
      expect(
        () => RuleEngine([
          const Creature(
            id: 'conditional_only',
            rarity: Rarity.rare,
            conditions: HatchConditions(minTouches: 1),
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('falls back when nothing else matches', () {
      final engine = RuleEngine([
        fallback,
        const Creature(
          id: 'needs_touches',
          rarity: Rarity.rare,
          conditions: HatchConditions(minTouches: 500),
          priority: 30,
        ),
      ]);

      expect(engine.select(context()).species, 0);
    });

    test('prefers the higher priority over an easier match', () {
      final engine = RuleEngine([
        fallback,
        const Creature(
          id: 'easy',
          rarity: Rarity.uncommon,
          conditions: HatchConditions(minTouches: 10),
          priority: 20,
        ),
        const Creature(
          id: 'hard',
          rarity: Rarity.epic,
          conditions: HatchConditions(minTouches: 100),
          priority: 60,
          speciesBase: 1,
        ),
      ]);

      // Someone at 200 touches satisfies both; the rarer one should win.
      expect(engine.select(context(touches: 200)).species, 1);
    });

    test('draws among equal priorities in proportion to weight', () {
      final engine = RuleEngine([
        const Creature(id: 'often', rarity: Rarity.common, weight: 90),
        const Creature(
          id: 'rarely',
          rarity: Rarity.common,
          weight: 10,
          speciesBase: 1,
        ),
      ], random: Random(7));

      final drawn = <int, int>{};
      for (var i = 0; i < 2000; i++) {
        final species = engine.select(context()).species;
        drawn[species] = (drawn[species] ?? 0) + 1;
      }

      expect(drawn[0], greaterThan(drawn[1]!));
      // Roughly 9:1; allow plenty of slack for a finite sample.
      expect(drawn[1]! / 2000, closeTo(0.10, 0.04));
    });

    test('always returns something, whatever the egg went through', () {
      final engine = RuleEngine(season01Creatures, random: Random(1));

      for (var hour = 0; hour < 24; hour++) {
        for (final touches in [0, 1, 199, 200, 500, 1000, 5000]) {
          for (final shakes in [0, 29, 30, 100, 200, 900]) {
            final result = engine.select(
              context(
                touches: touches,
                shakes: shakes,
                hatchedAt: DateTime(2026, 8, 24, hour, 30),
              ),
            );

            expect(result.species, inInclusiveRange(0, 287));
          }
        }
      }
    });
  });

  group('season 01 set', () {
    final engine = RuleEngine(season01Creatures, random: Random(3));

    test('gives a common to someone who did nothing', () {
      expect(engine.select(context()).rarity, Rarity.common);
    });

    test('gives the shaker something other than a common', () {
      expect(
        engine.select(context(shakes: 40)).species,
        inInclusiveRange(104, 135),
        reason: 'the shaker lands somewhere in the dizzy family',
      );
    });

    test('gives the small hours their own creature', () {
      final atDawn = context(hatchedAt: DateTime(2026, 8, 24, 3, 30));

      expect(
        engine.select(atDawn).species,
        inInclusiveRange(168, 195),
        reason: 'the small hours land somewhere in the ghost family',
      );
    });

    test('reserves the secret for someone who did all three', () {
      final everything = context(
        touches: 1200,
        shakes: 250,
        hatchedAt: DateTime(2026, 8, 24, 3, 30),
      );

      expect(engine.select(everything).rarity, Rarity.secret);
    });

    test('has unique ids', () {
      final ids = season01Creatures.map((creature) => creature.id).toSet();

      expect(ids, hasLength(season01Creatures.length));
    });

    test('covers every rarity the prototype claims', () {
      final rarities = season01Creatures
          .map((creature) => creature.rarity)
          .toSet();

      expect(rarities, equals(Rarity.values.toSet()));
    });

    test('tiles the species space with no gap and no overlap', () {
      // A name is registered against a species number. If a rule's slice moved
      // — a reorder, a changed count — a name somebody already registered
      // would start pointing at a different creature, and there is no way to
      // put that right afterwards.
      final owner = <int, String>{};

      for (final rule in season01Creatures) {
        for (var i = 0; i < rule.variants; i++) {
          final species = rule.speciesBase + i;
          expect(
            owner[species],
            isNull,
            reason: '$species is claimed by both ${owner[species]} and '
                '${rule.id}',
          );
          owner[species] = rule.id;
        }
      }

      expect(
        owner.length,
        CreatureAppearance.speciesCount,
        reason: 'the season has to fill exactly the space the shader can draw',
      );
      for (var species = 0; species < CreatureAppearance.speciesCount; species++) {
        expect(owner, contains(species), reason: 'nothing owns $species');
      }
    });
  });
}
