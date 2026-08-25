import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oddlet/features/creatures/creature_appearance.dart';
import 'package:oddlet/features/creatures/creature_labels.dart';
import 'package:oddlet/features/rules/creature.dart';
import 'package:oddlet/features/rules/season_01.dart';
import 'package:oddlet/l10n/app_localizations.dart';
import 'package:oddlet/l10n/app_localizations_en.dart';
import 'package:oddlet/l10n/app_localizations_ko.dart';

void main() {
  group('CreatureAppearance', () {
    final ghost = season01Creatures.firstWhere((c) => c.id == 'ghost_chick');

    test('looks the same every time the creature is found', () {
      expect(CreatureAppearance.of(ghost), CreatureAppearance.of(ghost));
    });

    test('gives each creature its own look', () {
      final looks = season01Creatures.map(CreatureAppearance.of).toSet();

      expect(looks, hasLength(season01Creatures.length));
    });

    test('keeps every creature within the shape the shader can draw', () {
      for (final creature in season01Creatures) {
        final appearance = CreatureAppearance.of(creature);

        expect(appearance.squash, inInclusiveRange(0.7, 1.6));
        expect(appearance.eyeSpacing, inInclusiveRange(0.2, 0.6));
        expect(appearance.eyeSize, inInclusiveRange(0.1, 0.35));
        expect(appearance.crestLength, inInclusiveRange(0.0, 0.6));
        expect(appearance.footSize, greaterThan(0));
      }
    });

    test('gives every creature a paler underside', () {
      for (final creature in season01Creatures) {
        final appearance = CreatureAppearance.of(creature);

        expect(
          HSVColor.fromColor(appearance.belly).value,
          greaterThan(HSVColor.fromColor(appearance.body).value),
        );
      }
    });

    test('never leaves a creature without a face', () {
      // A missing feature reads as damage rather than as variety, so every
      // creature carries the same parts and only their degree varies.
      for (final creature in season01Creatures) {
        final appearance = CreatureAppearance.of(creature);

        expect(appearance.beakSize, greaterThan(0), reason: creature.id);
        expect(appearance.footSize, greaterThan(0), reason: creature.id);
        expect(appearance.eyeSize, greaterThan(0), reason: creature.id);
      }
    });

    test('reserves the glow for the top tiers', () {
      for (final creature in season01Creatures) {
        if (creature.rarity.index < Rarity.legendary.index) {
          expect(
            CreatureAppearance.of(creature).glow,
            0,
            reason: '${creature.id} is not rare enough to glow',
          );
        }
      }
    });

    test('gives a marking a strength only when it has a marking', () {
      for (final creature in season01Creatures) {
        final appearance = CreatureAppearance.of(creature);

        expect(
          appearance.markStrength > 0,
          appearance.marking != CreatureMarking.none,
          reason: '${creature.id} disagrees about whether it is marked',
        );
      }
    });

    test('keeps a marking the same animal rather than paint on it', () {
      for (final creature in season01Creatures) {
        final appearance = CreatureAppearance.of(creature);
        if (appearance.marking == CreatureMarking.none) {
          continue;
        }

        final coat = HSVColor.fromColor(appearance.body);
        final mark = HSVColor.fromColor(appearance.markColor);

        expect(mark.hue, closeTo(coat.hue, 1));
        expect(mark.value, lessThan(coat.value));
      }
    });

    test('no two creatures in the season read as the same animal', () {
      final seen = <String, String>{};

      for (final creature in season01Creatures) {
        final signature = CreatureAppearance.of(creature).signature;
        final clash = seen[signature];

        expect(
          clash,
          isNull,
          reason:
              '${creature.id} looks like $clash ($signature). Bump the '
              "designSalt on one of them rather than renaming it.",
        );
        seen[signature] = creature.id;
      }
    });

    test('holds a season, and no more than a season', () {
      // Bounded on purpose. Open-ended generation would make every find a
      // first find, so nobody would ever meet a creature someone else named.
      expect(CreatureAppearance.speciesCount, inInclusiveRange(100, 600));

      final looks = <String>{};
      for (var i = 0; i < CreatureAppearance.speciesCount * 3; i++) {
        looks.add(CreatureAppearance.species(i, Rarity.common).signature);
      }

      expect(looks, hasLength(CreatureAppearance.speciesCount));
    });

    test('a species is the same creature for everyone who finds it', () {
      // Two people who reach species 42 must see the same animal, or a name
      // one of them registered means nothing to the other.
      for (final index in [0, 7, 42, 200]) {
        expect(
          CreatureAppearance.species(index, Rarity.common),
          CreatureAppearance.species(index, Rarity.common),
        );
      }
    });

    test('spends more of the oddity budget as the tier climbs', () {
      var previous = -1;
      for (final rarity in Rarity.values) {
        final budget = CreatureAppearance.oddityBudget(rarity);

        expect(budget, greaterThan(previous));
        previous = budget;
      }
    });
  });

  group('labels', () {
    final locales = <String, AppLocalizations>{
      'en': AppLocalizationsEn(),
      'ko': AppLocalizationsKo(),
    };

    test('every creature in the season has a name in every language', () {
      for (final entry in locales.entries) {
        for (final creature in season01Creatures) {
          final name = creatureName(entry.value, creature.id);

          expect(
            name,
            isNot(missingCreatureName),
            reason: '${creature.id} has no name in ${entry.key}',
          );
          expect(name, isNotEmpty);
        }
      }
    });

    test('names differ between languages where they should', () {
      // If Korean silently fell back to English these would match.
      expect(
        creatureName(locales['ko']!, 'ghost_chick'),
        isNot(creatureName(locales['en']!, 'ghost_chick')),
      );
    });

    test('every rarity has a label', () {
      for (final entry in locales.entries) {
        for (final rarity in Rarity.values) {
          expect(
            rarityLabel(entry.value, rarity),
            isNotEmpty,
            reason: '$rarity has no label in ${entry.key}',
          );
        }
      }
    });

    test('an unknown creature is flagged rather than shown as blank', () {
      expect(
        creatureName(locales['en']!, 'not_a_creature'),
        missingCreatureName,
      );
    });

    test('each rarity is told apart by colour as well as by name', () {
      const scheme = ColorScheme.dark();
      final colors = Rarity.values
          .map((rarity) => rarityColor(scheme, rarity))
          .toSet();

      expect(colors, hasLength(Rarity.values.length));
    });
  });
}
