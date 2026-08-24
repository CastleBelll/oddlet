import 'package:flutter/material.dart';

/// How one egg looks: its shell colour and the pattern across it.
///
/// Derived from the day rather than rolled at random, so today's egg keeps the
/// same face every time the app is opened. Appearance says nothing about what
/// is inside; it is there to make each day's egg feel like its own object.
@immutable
class EggAppearance {
  const EggAppearance({
    required this.shell,
    required this.speckle,
    required this.textureScale,
    required this.textureContrast,
    required this.blotchiness,
    required this.noiseOffset,
  });

  /// Pastel range: saturated shells read as plastic rather than shell.
  static const _minSaturation = 0.16;
  static const _maxSaturation = 0.34;
  static const _minValue = 0.72;
  static const _maxValue = 0.90;

  /// Speckles are the same hue, deeper and darker than the shell.
  static const _speckleSaturationBoost = 0.18;
  static const _speckleValueDrop = 0.30;

  /// Broad mottling at the low end, fine freckles at the high end.
  static const _minTextureScale = 8.0;
  static const _maxTextureScale = 14.0;
  static const _minTextureContrast = 0.14;
  static const _maxTextureContrast = 0.42;

  final Color shell;
  final Color speckle;

  /// Size of the pattern across the shell; larger means finer.
  final double textureScale;

  /// How strongly the pattern shows against the shell.
  final double textureContrast;

  /// 0 for even freckles, 1 for large soft blotches.
  final double blotchiness;

  /// Shifts the pattern so two eggs of the same scale still differ.
  final double noiseOffset;

  factory EggAppearance.forDay(DateTime day) {
    final ordinal = _dayOrdinal(day);

    final hue = _unit(ordinal, 1) * 360;
    final saturation = _lerp(_minSaturation, _maxSaturation, _unit(ordinal, 2));
    final value = _lerp(_minValue, _maxValue, _unit(ordinal, 3));

    return EggAppearance(
      shell: HSVColor.fromAHSV(1, hue, saturation, value).toColor(),
      speckle: HSVColor.fromAHSV(
        1,
        hue,
        (saturation + _speckleSaturationBoost).clamp(0.0, 1.0),
        (value - _speckleValueDrop).clamp(0.0, 1.0),
      ).toColor(),
      textureScale: _lerp(
        _minTextureScale,
        _maxTextureScale,
        _unit(ordinal, 4),
      ),
      textureContrast: _lerp(
        _minTextureContrast,
        _maxTextureContrast,
        _unit(ordinal, 5),
      ),
      blotchiness: _unit(ordinal, 6),
      noiseOffset: _unit(ordinal, 7) * 100,
    );
  }
}

/// Whole days since the epoch, so one calendar day is one egg.
///
/// TODO: take the day from server time once the daily egg is on the backend;
/// the device clock must not decide which egg the user gets.
int _dayOrdinal(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

double _lerp(double from, double to, double t) => from + (to - from) * t;

/// A stable value in [0, 1) for a day and a purpose.
///
/// Hand-rolled rather than `Random(seed)`, whose sequence Dart does not promise
/// to keep across releases. An egg must not change its face on an SDK upgrade.
double _unit(int ordinal, int salt) =>
    _mix32(ordinal * 0x9E3779B1 + salt) / 0x100000000;

int _mix32(int value) {
  var x = value & 0xFFFFFFFF;
  x = (x ^ (x >>> 16)) * 0x7FEB352D & 0xFFFFFFFF;
  x = (x ^ (x >>> 15)) * 0x846CA68B & 0xFFFFFFFF;
  return (x ^ (x >>> 16)) & 0xFFFFFFFF;
}
