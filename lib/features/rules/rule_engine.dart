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

  /// The one creature this egg becomes. Never null: the unconditional
  /// fallback guarantees a candidate.
  Creature select(HatchContext context) {
    final candidates = creatures
        .where((creature) => creature.conditions.matches(context))
        .toList();

    final topPriority = candidates
        .map((creature) => creature.priority)
        .reduce(max);
    final finalists = candidates
        .where((creature) => creature.priority == topPriority)
        .toList();

    return _drawByWeight(finalists);
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
