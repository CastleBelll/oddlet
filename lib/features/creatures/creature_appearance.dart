import 'package:flutter/material.dart';

/// How one creature looks.
///
/// Derived from its id, so a creature looks the same every time it is found and
/// no two come out identical. Placeholder art: the real direction is settled
/// before the full set is drawn.
@immutable
class CreatureAppearance {
  const CreatureAppearance({
    required this.body,
    required this.belly,
    required this.squash,
    required this.eyeSpacing,
    required this.eyeSize,
  });

  /// Brighter and more saturated than an egg. This is the payoff.
  static const _minSaturation = 0.38;
  static const _maxSaturation = 0.66;
  static const _minValue = 0.72;
  static const _maxValue = 0.94;

  /// Above 1 is wide and squat, below 1 is tall.
  static const _minSquash = 0.82;
  static const _maxSquash = 1.24;

  static const _minEyeSpacing = 0.26;
  static const _maxEyeSpacing = 0.52;
  static const _minEyeSize = 0.16;
  static const _maxEyeSize = 0.30;

  final Color body;
  final Color belly;
  final double squash;
  final double eyeSpacing;
  final double eyeSize;

  factory CreatureAppearance.forId(String id) {
    final seed = _hashString(id);

    final hue = _unit(seed, 1) * 360;
    final saturation = _lerp(_minSaturation, _maxSaturation, _unit(seed, 2));
    final value = _lerp(_minValue, _maxValue, _unit(seed, 3));

    return CreatureAppearance(
      body: HSVColor.fromAHSV(1, hue, saturation, value).toColor(),
      belly: HSVColor.fromAHSV(
        1,
        hue,
        (saturation * 0.45).clamp(0.0, 1.0),
        (value + 0.12).clamp(0.0, 1.0),
      ).toColor(),
      squash: _lerp(_minSquash, _maxSquash, _unit(seed, 4)),
      eyeSpacing: _lerp(_minEyeSpacing, _maxEyeSpacing, _unit(seed, 5)),
      eyeSize: _lerp(_minEyeSize, _maxEyeSize, _unit(seed, 6)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CreatureAppearance &&
      other.body == body &&
      other.belly == belly &&
      other.squash == squash &&
      other.eyeSpacing == eyeSpacing &&
      other.eyeSize == eyeSize;

  @override
  int get hashCode => Object.hash(body, belly, squash, eyeSpacing, eyeSize);
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
