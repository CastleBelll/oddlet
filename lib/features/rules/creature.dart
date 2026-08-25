import 'package:flutter/foundation.dart';

enum Rarity { common, uncommon, rare, epic, legendary, secret }

/// What the user actually did, measured at the moment the egg is opened.
///
/// Everything the rules may look at arrives here. Adding a new kind of input
/// later means adding a field here and a condition that reads it, never a new
/// branch in the engine.
@immutable
class HatchContext {
  HatchContext({
    required this.touchCount,
    required this.shakeCount,
    required this.hatchedAt,
  }) : assert(
         !hatchedAt.isUtc,
         'hatchedAt must be in the user\'s own time. Time conditions ask what '
         'hour it is where the user is, so a UTC instant would make 3am '
         'happen at the same moment worldwide, which is the middle of the '
         'afternoon for most of it. Convert server time to local before it '
         'gets here.',
       );

  final int touchCount;
  final int shakeCount;
  final DateTime hatchedAt;
}

/// A range of wall-clock time, which may run past midnight.
///
/// Read off the clock on the wall rather than from an instant, so the same
/// window means the same thing to someone in Seoul and someone in São Paulo:
/// each of them gets it in their own small hours.
///
/// Windows shorter than an hour are a trap where daylight saving applies. The
/// clock can skip an hour outright in spring, and a window inside the skipped
/// hour would be unreachable that day for a whole country.
@immutable
class HatchWindow {
  const HatchWindow({required this.fromMinute, required this.toMinute});

  factory HatchWindow.between(int fromHour, int toHour) => HatchWindow(
    fromMinute: fromHour * Duration.minutesPerHour,
    toMinute: toHour * Duration.minutesPerHour,
  );

  /// Minutes since midnight. [toMinute] is exclusive.
  final int fromMinute;
  final int toMinute;

  bool contains(DateTime moment) {
    final minute = moment.hour * Duration.minutesPerHour + moment.minute;

    // A window like 23:00-02:00 wraps, so it is the union of two spans.
    if (fromMinute <= toMinute) {
      return minute >= fromMinute && minute < toMinute;
    }
    return minute >= fromMinute || minute < toMinute;
  }
}

/// What came out of an egg.
///
/// The species is the identity: it is what has a look, what a name is
/// registered against, and what fills a slot in the collection. The rule that
/// produced it is not kept, because two rules meeting in the same species
/// would be the same creature and the user has no way of telling them apart.
@immutable
class Hatchling {
  const Hatchling({required this.species, required this.rarity});

  final int species;
  final Rarity rarity;

  @override
  bool operator ==(Object other) =>
      other is Hatchling && other.species == species && other.rarity == rarity;

  @override
  int get hashCode => Object.hash(species, rarity);
}

/// What must be true for a creature to be a candidate.
///
/// Every field is optional and every one present must hold. No conditions at
/// all means the creature is always a candidate, which is what makes a
/// fallback possible.
@immutable
class HatchConditions {
  const HatchConditions({this.minTouches, this.minShakes, this.hatchWindow});

  static const always = HatchConditions();

  final int? minTouches;
  final int? minShakes;
  final HatchWindow? hatchWindow;

  bool get isUnconditional =>
      minTouches == null && minShakes == null && hatchWindow == null;

  bool matches(HatchContext context) {
    final minTouches = this.minTouches;
    if (minTouches != null && context.touchCount < minTouches) {
      return false;
    }

    final minShakes = this.minShakes;
    if (minShakes != null && context.shakeCount < minShakes) {
      return false;
    }

    final hatchWindow = this.hatchWindow;
    if (hatchWindow != null && !hatchWindow.contains(context.hatchedAt)) {
      return false;
    }

    return true;
  }
}

/// One possible outcome of opening an egg.
///
/// Carries no display name: names are copy, and copy lives in the ARB files
/// keyed by [id].
@immutable
class Creature {
  const Creature({
    required this.id,
    required this.rarity,
    this.conditions = HatchConditions.always,
    this.priority = 0,
    this.weight = 100,
    this.designSalt = 0,
    this.variants = 1,
    this.speciesBase = 0,
  }) : assert(weight > 0, 'a creature with no weight can never be drawn'),
       assert(
         variants > 0,
         'a rule that produces nothing cannot be an outcome',
       );

  final String id;

  /// How many species this rule can produce.
  ///
  /// A rule is not a creature. It settles the tier and the family; which of
  /// that family turns up is settled by what the user actually did. Without
  /// this the season holds as many species as it has rules, and the naming in
  /// §5.2 of the plan runs out in a week.
  final int variants;

  /// The first species number this rule owns.
  ///
  /// Written out in the season rather than counted from the order of the list,
  /// so that reordering the rules cannot silently point a name somebody has already
  /// registered at a different creature. A test checks the bases and variants
  /// tile the space with no gap and no overlap.
  final int speciesBase;
  final Rarity rarity;
  final HatchConditions conditions;

  /// Higher wins outright. A creature with a rarer set of conditions should
  /// beat an easier one the user also happens to satisfy.
  final int priority;

  /// Relative chance among candidates that tie on [priority].
  final int weight;

  /// Nudges this creature's generated look without changing its id.
  ///
  /// Two creatures can land on the same look by chance. Renaming one would
  /// break every collection that already holds it, so the look is moved
  /// instead. Bump this by one until the catalogue test passes.
  final int designSalt;
}
