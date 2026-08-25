import 'creature.dart';

/// Season 01 prototype set.
///
/// Nine outcomes, enough to tell whether the loop is fun before drawing the
/// full thirty. Only touches, shakes and the hour of hatching are used, because
/// those are the only inputs the app measures so far.
///
/// Reading these thresholds tells you how to get each creature. That is fine
/// here and never fine in the app: the user is meant to guess.
///
/// Tuned low on purpose. PHASE 0 is asking whether discovery is fun at all,
/// and nobody finds that out from a week of commons. Tighten these once the
/// loop has earned it.
const season01Creatures = <Creature>[
  // Fallbacks. One of these answers an egg that met no other condition, so
  // doing nothing still gives you something.
  Creature(
    id: 'plain_chick',
    speciesBase: 0,
    rarity: Rarity.common,
    weight: 100,
    variants: 64,
  ),
  Creature(
    id: 'sleepy_chick',
    speciesBase: 64,
    rarity: Rarity.common,
    weight: 55,
    variants: 40,
  ),

  Creature(
    id: 'dizzy_chick',
    speciesBase: 104,
    rarity: Rarity.uncommon,
    variants: 32,
    conditions: HatchConditions(minShakes: 10),
    priority: 20,
  ),
  Creature(
    id: 'angry_chick',
    speciesBase: 136,
    rarity: Rarity.uncommon,
    variants: 32,
    conditions: HatchConditions(minTouches: 50),
    priority: 20,
  ),

  Creature(
    id: 'ghost_chick',
    speciesBase: 168,
    rarity: Rarity.rare,
    variants: 28,
    // Widened from a single hour: a one hour window is unreachable by
    // accident, and this creature exists to be stumbled into.
    conditions: HatchConditions(
      hatchWindow: HatchWindow(fromMinute: 120, toMinute: 300),
    ),
    priority: 30,
  ),
  Creature(
    id: 'static_chick',
    speciesBase: 196,
    rarity: Rarity.rare,
    variants: 28,
    conditions: HatchConditions(minTouches: 150),
    priority: 35,
    weight: 80,
  ),

  Creature(
    id: 'storm_chick',
    speciesBase: 224,
    rarity: Rarity.epic,
    variants: 24,
    conditions: HatchConditions(minTouches: 100, minShakes: 35),
    priority: 60,
    weight: 40,
  ),

  Creature(
    id: 'dawn_runner',
    speciesBase: 248,
    rarity: Rarity.legendary,
    variants: 24,
    conditions: HatchConditions(
      minShakes: 25,
      hatchWindow: HatchWindow(fromMinute: 240, toMinute: 420),
    ),
    priority: 80,
    weight: 20,
  ),

  // The one nobody should find by accident.
  Creature(
    id: 'the_quiet_one',
    speciesBase: 272,
    rarity: Rarity.secret,
    variants: 16,
    conditions: HatchConditions(
      minTouches: 300,
      minShakes: 60,
      // The same small hours as the ghost. What makes this one hard is the
      // handling, not an hour that some countries skip entirely.
      hatchWindow: HatchWindow(fromMinute: 120, toMinute: 300),
    ),
    priority: 99,
    weight: 10,
  ),
];

/// How many species this season holds, which has to match the number of looks
/// the shader can draw.
///
/// Fixed for the life of the season. Moving a rule's share of the space would
/// point a name that somebody already registered at a different creature.
int get season01SpeciesCount =>
    season01Creatures.fold(0, (total, rule) => total + rule.variants);

/// Which tier a species belongs to, or null if it is not in this season.
Rarity? season01RarityOf(int species) {
  for (final rule in season01Creatures) {
    if (species >= rule.speciesBase &&
        species < rule.speciesBase + rule.variants) {
      return rule.rarity;
    }
  }
  return null;
}

/// Every species in a tier, in order, which is the shape of one section of the
/// collection.
List<int> season01SpeciesIn(Rarity rarity) => [
  for (final rule in season01Creatures)
    if (rule.rarity == rarity)
      ...List.generate(rule.variants, (i) => rule.speciesBase + i),
];
