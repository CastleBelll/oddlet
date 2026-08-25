import 'dart:math';

import 'creature.dart';

/// Picks what an egg becomes from what the user did to it.
///
/// Deliberately knows nothing about any particular creature: everything that
/// varies lives in the creature list, so adding an outcome is a data change.
class RuleEngine {
  /// Throws [ArgumentError] unless the set can answer every possible egg.
  /// Better to fail at startup than to leave a user holding an egg that
  /// cannot open.
  RuleEngine(this.creatures, {Random? random}) : _random = random ?? Random() {
    if (creatures.isEmpty) {
      throw ArgumentError.value(creatures, 'creatures', 'must not be empty');
    }
    if (!creatures.any((creature) => creature.conditions.isUnconditional)) {
      throw ArgumentError.value(
        creatures,
        'creatures',
        'needs at least one creature with no conditions, as the fallback for '
            'an egg that met none of them',
      );
    }
  }

  final List<Creature> creatures;
  final Random _random;

  /// What this egg becomes. Never null: the unconditional fallback guarantees
  /// a candidate.
  Hatchling select(HatchContext context) {
    final candidates = creatures
        .where((creature) => creature.conditions.matches(context))
        .toList();

    final topPriority = candidates
        .map((creature) => creature.priority)
        .reduce(max);
    final finalists = candidates
        .where((creature) => creature.priority == topPriority)
        .toList();

    final rule = _drawByWeight(finalists);
    return Hatchling(species: _speciesFor(rule, context), rarity: rule.rarity);
  }

  /// Which of a rule's species this egg is.
  ///
  /// Read off what the user did rather than rolled, and read off it coarsely.
  /// Coarse is the point: two people who handled their eggs about the same way
  /// on about the same kind of day have to land on the same species, or nobody
  /// ever meets a creature somebody else named and the naming in §5.2 has no
  /// shared world to hang a name in.
  int _speciesFor(Creature rule, HatchContext context) {
    final base = rule.speciesBase;
    if (rule.variants == 1) {
      return base;
    }

    final handling = context.touchCount ~/ _touchesPerBand;
    final shaking = context.shakeCount ~/ _shakesPerBand;
    final timeOfDay = context.hatchedAt.hour ~/ _hoursPerBand;

    var seed = _hashString(rule.id);
    seed = _mix(seed + handling * 0x9E3779B1);
    seed = _mix(seed + shaking * 0x85EBCA6B);
    seed = _mix(seed + timeOfDay * 0xC2B2AE35);

    return base + seed % rule.variants;
  }

  Creature _drawByWeight(List<Creature> finalists) {
    if (finalists.length == 1) {
      return finalists.single;
    }

    final total = finalists.fold(0, (sum, creature) => sum + creature.weight);
    var roll = _random.nextInt(total);

    for (final creature in finalists) {
      roll -= creature.weight;
      if (roll < 0) {
        return creature;
      }
    }

    // Unreachable: the weights sum to exactly `total`.
    return finalists.last;
  }
}

/// How coarsely the hidden inputs are read when settling a species.
///
/// Wide on purpose. Narrow bands would give almost every egg its own species,
/// which is the open space §5.2 warns about: every find a first find, and no
/// creature anyone else has already named.
const _touchesPerBand = 12;
const _shakesPerBand = 5;
const _hoursPerBand = 3;

int _hashString(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash = (hash ^ unit) * 0x01000193 & 0xFFFFFFFF;
  }
  return hash;
}

/// Dart does not promise Random(seed) gives the same sequence between
/// releases, and a species that moved between app versions would move a name
/// with it. This is written out so it cannot.
int _mix(int value) {
  var x = value & 0xFFFFFFFF;
  x = (x ^ (x >>> 16)) * 0x7FEB352D & 0xFFFFFFFF;
  x = (x ^ (x >>> 15)) * 0x846CA68B & 0xFFFFFFFF;
  return (x ^ (x >>> 16)) & 0xFFFFFFFF;
}
