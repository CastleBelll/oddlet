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
        expect(appearance.eyeCount, inInclusiveRange(1, 3));
        expect(appearance.earLength, inInclusiveRange(0.0, 0.9));
        expect(appearance.bumpiness, inInclusiveRange(0.0, 1.0));
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

    test('keeps commons plain and lets the rare ones be strange', () {
      for (final creature in season01Creatures) {
        final appearance = CreatureAppearance.of(creature);

        if (creature.rarity == Rarity.common) {
          expect(appearance.earLength, 0, reason: 'a common has no horns');
          expect(appearance.lumpRadius, 0);
          expect(appearance.bumpiness, 0);
          expect(appearance.eyeCount, 2);
          expect(appearance.glow, 0);
        }
        if (creature.rarity.index < Rarity.epic.index) {
          expect(appearance.eyeCount, 2, reason: 'odd eyes are for odd tiers');
        }
        if (creature.rarity.index < Rarity.legendary.index) {
          expect(appearance.glow, 0, reason: 'only the rare ones glow');
        }
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
