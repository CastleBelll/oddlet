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
/// Every creature has the same parts: a body, a beak, two eyes, two feet.
/// None is ever left off. A face missing a feature reads as wrong rather than
/// as different, which is how an earlier set ended up looking like damaged
/// animals instead of a family of them.
///
/// Rarity buys degree, not deformity: a bolder crest, a stronger coat, and at
/// the top a glow. Everything else varies by proportion and colour.
@immutable
class CreatureAppearance {
  const CreatureAppearance({
    required this.body,
    required this.belly,
    required this.squash,
    required this.eyeSpacing,
    required this.eyeSize,
    required this.crestLength,
    required this.crestSpread,
    required this.crestRadius,
    required this.footSize,
    required this.glow,
    required this.marking,
    required this.markScale,
    required this.markStrength,
    required this.markColor,
    required this.beakSize,
    required this.beakColor,
    required this.species,
  });

  /// Which of the season's species this is. Two creatures sharing it are the
  /// same creature, which is what a first discovery can be claimed against.
  final int species;

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
  // Kept modest. Oversized eyes on a small body stop reading as cute and
  // start reading as empty sockets.
  static const _minEyeSize = 0.13;
  static const _maxEyeSize = 0.24;

  final Color body;
  final Color belly;

  final double squash;
  final double eyeSpacing;
  final double eyeSize;

  /// A tuft of down on the head. 0 for a creature without one.
  final double crestLength;
  final double crestSpread;
  final double crestRadius;

  final double footSize;

  /// Extra rim light, reserved for the rare ones.
  final double glow;

  /// Which coat pattern this one wears.
  final CreatureMarking marking;
  final double markScale;
  final double markStrength;
  final Color markColor;

  /// 0 for a creature with no beak.
  final double beakSize;
  final Color beakColor;

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
  String get signature => 'species$species';

  /// How many creatures a season can hold.
  ///
  /// Deliberately small. The point of a bounded set is that two people can
  /// find the same creature: if the space were open, every find would be a
  /// first find, nobody would ever meet a creature someone else had named,
  /// and there would be no shared world to talk about.
  static const speciesCount = _hues * _proportions * _crests * _markingKinds;

  static const _hues = 8;
  static const _proportions = 3;
  static const _crests = 3;
  static const _markingKinds = 4;

  factory CreatureAppearance.of(Creature creature) => CreatureAppearance.species(
    _hashString(creature.id) ^ (creature.designSalt * 0x9E3779B1),
    creature.rarity,
  );

  /// The look of one species.
  ///
  /// Everything is decided by [species] alone, so the same species is the
  /// same creature down to the pixel for everyone who finds it. That is what
  /// lets one person name it for everybody else.
  factory CreatureAppearance.species(int species, Rarity rarity) {
    final index = species.abs() % speciesCount;
    final budget = oddityBudget(rarity);

    var rest = index;
    final hueSlot = rest % _hues;
    rest ~/= _hues;
    final proportionSlot = rest % _proportions;
    rest ~/= _proportions;
    final crestSlot = rest % _crests;
    rest ~/= _crests;
    final markingSlot = rest % _markingKinds;

    final hue = hueSlot * (360 / _hues);
    final saturation =
        _lerp(_minSaturation, _maxSaturation, hueSlot / (_hues - 1));
    final value = _lerp(_minValue, _maxValue, proportionSlot / 2);

    final squash = _lerp(_minSquash, _maxSquash, proportionSlot / 2);
    final hasCrest = crestSlot > 0;
    final markings = CreatureMarking.values[markingSlot];

    // Reads from the slots rather than from fresh randomness, so nothing
    // varies between two sightings of the same species.
    final seed = index;

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
      crestLength: hasCrest ? _lerp(0.20, 0.36, (crestSlot - 1) / 1) : 0,
      crestSpread: _lerp(0.08, 0.22, _unit(seed, 16)),
      crestRadius: _lerp(0.06, 0.11, _unit(seed, 17)),
      footSize: _lerp(0.13, 0.19, _unit(seed, 18)),
      glow: budget >= 4 ? _lerp(0.25, 0.55, _unit(seed, 21)) : 0,
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
      // Never zero. The beak is what makes one of these read as a chick.
      beakSize: _lerp(0.16, 0.23, _unit(seed, 30)),
      // Warm and light against the coat, the way a real beak is.
      species: index,
      beakColor: HSVColor.fromAHSV(
        1,
        _lerp(28, 52, _unit(seed, 31)),
        _lerp(0.55, 0.85, _unit(seed, 32)),
        _lerp(0.86, 0.98, _unit(seed, 33)),
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
      other.crestLength == crestLength &&
      other.crestSpread == crestSpread &&
      other.crestRadius == crestRadius &&
      other.footSize == footSize &&
      other.glow == glow &&
      other.marking == marking &&
      other.markScale == markScale &&
      other.markStrength == markStrength &&
      other.markColor == markColor &&
      other.beakSize == beakSize &&
      other.beakColor == beakColor &&
      other.species == species;

  @override
  int get hashCode => Object.hashAll([
    body,
    belly,
    squash,
    eyeSpacing,
    eyeSize,
    crestLength,
    crestSpread,
    crestRadius,
    footSize,
    glow,
    marking,
    markScale,
    markStrength,
    markColor,
    beakSize,
    beakColor,
    species,
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
