import 'package:flutter/foundation.dart';

enum Rarity { common, uncommon, rare, epic, legendary, secret }

/// What the user actually did, measured at the moment the egg is opened.
///
/// Everything the rules may look at arrives here. Adding a new kind of input
/// later means adding a field here and a condition that reads it, never a new
/// branch in the engine.
@immutable
class HatchContext {
  const HatchContext({
    required this.touchCount,
    required this.shakeCount,
    required this.hatchedAt,
  });

  final int touchCount;
  final int shakeCount;
  final DateTime hatchedAt;
}

/// A time of day range, which may run past midnight.
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
  }) : assert(weight > 0, 'a creature with no weight can never be drawn');

  final String id;
  final Rarity rarity;
  final HatchConditions conditions;

  /// Higher wins outright. A creature with a rarer set of conditions should
  /// beat an easier one the user also happens to satisfy.
  final int priority;

  /// Relative chance among candidates that tie on [priority].
  final int weight;
}
