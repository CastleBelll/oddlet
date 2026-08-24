import 'package:flutter/material.dart';

import '../rules/creature.dart';

/// The coat patterns a creature can wear. A small vocabulary rather than a
/// free parameter, so every creature reads as belonging to the same world.
enum CreatureMarking { none, spots, stripes, eyeMask }

/// How one creature looks.
///
/// Assembled rather than drawn: a body, and whichever parts this creature was
/// given. Everything comes from its id, so a creature looks the same every
/// time anyone finds it, which is what lets players compare notes.
///
/// Rarity is the budget, but only for what is genuinely strange. Ears, a
/// mouth and markings are ordinary equipment: a spotted animal with ears is
/// not odd, it is an animal. What a tier buys is a second fused mass, a lumpy
/// hide, an eye count other than two, and finally a glow.
///
/// Splitting it this way keeps rarity legible at a glance while leaving the
/// common tier enough room to hold dozens of creatures that still look
/// different from each other.
@immutable
class CreatureAppearance {
  const CreatureAppearance({
    required this.body,
    required this.belly,
    required this.squash,
    required this.eyeSpacing,
    required this.eyeSize,
    required this.eyeCount,
    required this.earLength,
    required this.earSpread,
    required this.earRadius,
    required this.lumpHeight,
    required this.lumpRadius,
    required this.bumpiness,
    required this.glow,
    required this.mouthWidth,
    required this.mouthHeight,
    required this.marking,
    required this.markScale,
    required this.markStrength,
    required this.markColor,
  });

  /// Brighter and more saturated than an egg. This is the payoff.
  static const _minSaturation = 0.38;
  static const _maxSaturation = 0.66;
  static const _minValue = 0.72;
  static const _maxValue = 0.94;

  /// Above 1 is wide and squat, below 1 is tall.
  static const _minSquash = 0.78;
  static const _maxSquash = 1.30;

  static const _minEyeSpacing = 0.24;
  static const _maxEyeSpacing = 0.54;
  static const _minEyeSize = 0.15;
  static const _maxEyeSize = 0.32;

  final Color body;
  final Color belly;

  final double squash;
  final double eyeSpacing;
  final double eyeSize;

  /// 1, 2 or 3. Two is ordinary; anything else is a sign of something odd.
  final int eyeCount;

  /// 0 for a creature with no ears or horns.
  final double earLength;
  final double earSpread;
  final double earRadius;

  /// A second mass fused onto the body. 0 for a single lump of an animal.
  final double lumpHeight;
  final double lumpRadius;

  /// 0 smooth, 1 a lumpy hide.
  final double bumpiness;

  /// Extra rim light, reserved for the rare ones.
  final double glow;

  /// 0 for a creature with no mouth.
  final double mouthWidth;
  final double mouthHeight;

  /// Which coat pattern this one wears.
  final CreatureMarking marking;
  final double markScale;
  final double markStrength;
  final Color markColor;

  /// How many oddities this creature may carry, by tier.
  static int oddityBudget(Rarity rarity) => switch (rarity) {
    Rarity.common => 0,
    Rarity.uncommon => 1,
    Rarity.rare => 2,
    Rarity.epic => 3,
    Rarity.legendary => 4,
    Rarity.secret => 5,
  };

  /// The parts of a look a person tells apart at a glance.
  ///
  /// Two creatures with the same signature read as the same animal in a
  /// different shade, however far apart their exact numbers are. The season
  /// catalogue is tested for duplicates, and [Creature.designSalt] is how one
  /// is nudged apart without renaming it.
  String get signature {
    final hueBucket = (HSVColor.fromColor(body).hue ~/ 30).clamp(0, 11);
    final proportion = squash < 0.95 ? 'tall' : (squash < 1.12 ? 'round' : 'wide');
    final ears = earLength == 0 ? 0 : (earLength < 0.55 ? 1 : 2);
    final lump = lumpRadius == 0 ? 0 : (lumpRadius < 0.41 ? 1 : 2);
    final mouth = mouthWidth == 0 ? 0 : (mouthWidth < 0.18 ? 1 : 2);
    final hide = bumpiness == 0 ? 0 : 1;

    return 'h$hueBucket/$proportion/ear$ears/lump$lump/'
        'eye$eyeCount/mouth$mouth/${marking.name}/hide$hide';
  }

  factory CreatureAppearance.of(Creature creature) {
    final seed = _hashString(creature.id) ^ (creature.designSalt * 0x9E3779B1);
    final budget = oddityBudget(creature.rarity);

    final hue = _unit(seed, 1) * 360;
    final saturation = _lerp(_minSaturation, _maxSaturation, _unit(seed, 2));
    final value = _lerp(_minValue, _maxValue, _unit(seed, 3));

    // Proportions drift further from ordinary as the tier climbs.
    final stretch = 1 + budget / 12;
    final squash = _lerp(
      _minSquash,
      _maxSquash,
      _unit(seed, 4),
    ).clamp(_minSquash, _maxSquash * stretch);

    // Ordinary equipment, open to every tier.
    final hasEars = _unit(seed, 10) > 0.30;
    final hasMouth = _unit(seed, 22) > 0.30;
    final markings = _unit(seed, 23) > 0.35
        ? CreatureMarking.values[1 + (_unit(seed, 24) * 3).floor().clamp(0, 2)]
        : CreatureMarking.none;

    // Bought with the oddity budget.
    final hasLump = budget >= 1 && _unit(seed, 11) > 0.45;
    final isBumpy = budget >= 2 && _unit(seed, 12) > 0.45;

    // Two eyes is the norm. Only the strange ones look back with more or less.
    final oddEyes = budget >= 3 && _unit(seed, 13) > 0.5;
    final eyeCount = oddEyes ? (_unit(seed, 14) > 0.5 ? 3 : 1) : 2;

    return CreatureAppearance(
      body: HSVColor.fromAHSV(1, hue, saturation, value).toColor(),
      belly: HSVColor.fromAHSV(
        1,
        hue,
        (saturation * 0.45).clamp(0.0, 1.0),
        (value + 0.12).clamp(0.0, 1.0),
      ).toColor(),
      squash: squash,
      eyeSpacing: _lerp(_minEyeSpacing, _maxEyeSpacing, _unit(seed, 5)),
      eyeSize: _lerp(_minEyeSize, _maxEyeSize, _unit(seed, 6)),
      eyeCount: eyeCount,
      earLength: hasEars ? _lerp(0.30, 0.85, _unit(seed, 15)) : 0,
      earSpread: _lerp(0.22, 0.46, _unit(seed, 16)),
      earRadius: _lerp(0.09, 0.19, _unit(seed, 17)),
      lumpHeight: _lerp(0.34, 0.62, _unit(seed, 18)),
      lumpRadius: hasLump ? _lerp(0.30, 0.52, _unit(seed, 19)) : 0,
      bumpiness: isBumpy ? _lerp(0.35, 1.0, _unit(seed, 20)) : 0,
      glow: budget >= 4 ? _lerp(0.25, 0.55, _unit(seed, 21)) : 0,
      mouthWidth: hasMouth ? _lerp(0.10, 0.26, _unit(seed, 25)) : 0,
      mouthHeight: _lerp(0.06, 0.16, _unit(seed, 26)),
      marking: markings,
      markScale: _lerp(4.0, 11.0, _unit(seed, 27)),
      markStrength: markings == CreatureMarking.none
          ? 0
          : _lerp(0.30, 0.70, _unit(seed, 28)),
      // Same hue as the coat, darker: a marking should look like the same
      // animal, not like paint.
      markColor: HSVColor.fromAHSV(
        1,
        hue,
        (saturation + 0.12).clamp(0.0, 1.0),
        (value - 0.34).clamp(0.0, 1.0),
      ).toColor(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CreatureAppearance &&
      other.body == body &&
      other.belly == belly &&
      other.squash == squash &&
      other.eyeSpacing == eyeSpacing &&
      other.eyeSize == eyeSize &&
      other.eyeCount == eyeCount &&
      other.earLength == earLength &&
      other.earSpread == earSpread &&
      other.earRadius == earRadius &&
      other.lumpHeight == lumpHeight &&
      other.lumpRadius == lumpRadius &&
      other.bumpiness == bumpiness &&
      other.glow == glow &&
      other.mouthWidth == mouthWidth &&
      other.mouthHeight == mouthHeight &&
      other.marking == marking &&
      other.markScale == markScale &&
      other.markStrength == markStrength &&
      other.markColor == markColor;

  @override
  int get hashCode => Object.hashAll([
    body,
    belly,
    squash,
    eyeSpacing,
    eyeSize,
    eyeCount,
    earLength,
    earSpread,
    earRadius,
    lumpHeight,
    lumpRadius,
    bumpiness,
    glow,
    mouthWidth,
    mouthHeight,
    marking,
    markScale,
    markStrength,
    markColor,
  ]);
}

double _lerp(double from, double to, double t) => from + (to - from) * t;

int _hashString(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash = (hash ^ unit) * 0x01000193 & 0xFFFFFFFF;
  }
  return hash;
}

/// A stable value in [0, 1) for a creature and a purpose.
double _unit(int seed, int salt) =>
    _mix32(seed * 0x9E3779B1 + salt) / 0x100000000;

int _mix32(int value) {
  var x = value & 0xFFFFFFFF;
  x = (x ^ (x >>> 16)) * 0x7FEB352D & 0xFFFFFFFF;
  x = (x ^ (x >>> 15)) * 0x846CA68B & 0xFFFFFFFF;
  return (x ^ (x >>> 16)) & 0xFFFFFFFF;
}
