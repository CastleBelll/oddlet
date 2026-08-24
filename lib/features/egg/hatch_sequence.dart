/// Timing for the moment the app is actually about.
///
/// Kept as plain functions of elapsed progress so the shape of the sequence can
/// be reasoned about and tested without running an animation. The whole run is
/// expressed as a fraction `t` in [0, 1] of [hatchDuration].
library;

import 'dart:math' as math;

/// Long enough to build, short enough that nobody sits through it twice.
const hatchDuration = Duration(milliseconds: 2800);

/// Boundaries between stages, as fractions of the run.
const _trembleEnd = 0.28;
const _crackEnd = 0.78;
const _breakEnd = 0.90;

/// How many times the shell gives way. A shell fails in lurches, not by
/// dissolving evenly.
const _lurches = 3;

enum HatchStage { trembling, cracking, breaking, blackout, done }

HatchStage hatchStageAt(double t) {
  if (t < _trembleEnd) {
    return HatchStage.trembling;
  }
  if (t < _crackEnd) {
    return HatchStage.cracking;
  }
  if (t < _breakEnd) {
    return HatchStage.breaking;
  }
  if (t < 1) {
    return HatchStage.blackout;
  }
  return HatchStage.done;
}

/// 0 while the shell is whole, 1 once it has split open.
double crackProgressAt(double t) {
  if (t <= _trembleEnd) {
    return 0;
  }
  if (t >= _crackEnd) {
    return 1;
  }

  final within = (t - _trembleEnd) / (_crackEnd - _trembleEnd);
  final lurch = (within * _lurches).floor();
  final intoLurch = within * _lurches - lurch;

  // Each lurch snaps open and settles, rather than creeping.
  final eased = 1 - math.pow(1 - intoLurch, 3).toDouble();
  return ((lurch + eased) / _lurches).clamp(0.0, 1.0);
}

/// How hard the shell is shaking, 0 to 1.
double trembleAt(double t) {
  if (t >= _breakEnd) {
    return 0;
  }
  if (t < _trembleEnd) {
    return t / _trembleEnd; // something inside is waking up
  }
  return 1;
}

/// Opacity of the white flash as the shell gives way.
double flashAt(double t) {
  if (t < _crackEnd || t >= 1) {
    return 0;
  }
  if (t < _breakEnd) {
    return (t - _crackEnd) / (_breakEnd - _crackEnd);
  }

  // Gone well before the blackout finishes, so the dark has the last word.
  final intoBlackout = (t - _breakEnd) / (1 - _breakEnd);
  return (1 - intoBlackout * 2).clamp(0.0, 1.0);
}

/// Opacity of the dark that the reveal will open out of.
double blackoutAt(double t) {
  if (t < _breakEnd) {
    return 0;
  }
  return ((t - _breakEnd) / (1 - _breakEnd)).clamp(0.0, 1.0);
}

/// The shell itself fades as it comes apart.
double shellOpacityAt(double t) {
  if (t < _crackEnd) {
    return 1;
  }
  if (t >= _breakEnd) {
    return 0;
  }
  return 1 - (t - _crackEnd) / (_breakEnd - _crackEnd);
}
