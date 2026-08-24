import 'creature.dart';

/// Season 01 prototype set.
///
/// Nine outcomes, enough to tell whether the loop is fun before drawing the
/// full thirty. Only touches, shakes and the hour of hatching are used, because
/// those are the only inputs the app measures so far.
///
/// Reading these thresholds tells you how to get each creature. That is fine
/// here and never fine in the app: the user is meant to guess.
const season01Creatures = <Creature>[
  // Fallbacks. One of these answers an egg that met no other condition, so
  // doing nothing still gives you something.
  Creature(id: 'plain_chick', rarity: Rarity.common, weight: 100),
  Creature(id: 'sleepy_chick', rarity: Rarity.common, weight: 55),

  Creature(
    id: 'dizzy_chick',
    rarity: Rarity.uncommon,
    conditions: HatchConditions(minShakes: 30),
    priority: 20,
  ),
  Creature(
    id: 'angry_chick',
    rarity: Rarity.uncommon,
    conditions: HatchConditions(minTouches: 200),
    priority: 20,
  ),

  Creature(
    id: 'ghost_chick',
    rarity: Rarity.rare,
    conditions: HatchConditions(
      hatchWindow: HatchWindow(fromMinute: 180, toMinute: 240),
    ),
    priority: 30,
  ),
  Creature(
    id: 'static_chick',
    rarity: Rarity.rare,
    conditions: HatchConditions(minTouches: 500),
    priority: 35,
    weight: 80,
  ),

  Creature(
    id: 'storm_chick',
    rarity: Rarity.epic,
    conditions: HatchConditions(minTouches: 300, minShakes: 100),
    priority: 60,
    weight: 40,
  ),

  Creature(
    id: 'dawn_runner',
    rarity: Rarity.legendary,
    conditions: HatchConditions(
      minShakes: 80,
      hatchWindow: HatchWindow(fromMinute: 240, toMinute: 360),
    ),
    priority: 80,
    weight: 20,
  ),

  // The one nobody should find by accident.
  Creature(
    id: 'the_quiet_one',
    rarity: Rarity.secret,
    conditions: HatchConditions(
      minTouches: 1000,
      minShakes: 200,
      hatchWindow: HatchWindow(fromMinute: 180, toMinute: 240),
    ),
    priority: 99,
    weight: 10,
  ),
];
