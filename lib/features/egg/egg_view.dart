import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'egg_appearance.dart';
import 'shake_detector.dart';

const _pokeDecayPerSecond = 6.5;
const _pokeFrequency = 4.5; // hertz

/// Decaying oscillation behind the squash-and-rock response to a tap:
/// 1.0 at the moment of contact, ringing down to zero.
@visibleForTesting
double pokeAmplitude(double seconds) {
  if (seconds <= 0) {
    return seconds == 0 ? 1.0 : 0.0;
  }
  return math.exp(-_pokeDecayPerSecond * seconds) *
      math.cos(2 * math.pi * _pokeFrequency * seconds);
}

/// The egg the user keeps for the day.
///
/// Rendered in 3D by a raymarching fragment shader, so it takes real lighting
/// and the user can drag to orbit the camera around it.
class EggView extends StatefulWidget {
  const EggView({
    super.key,
    required this.height,
    required this.appearance,
    this.shakes,
  });

  final double height;

  /// Colour and pattern of this particular egg.
  final EggAppearance appearance;

  /// Shakes of the device, which knock the egg about harder than a tap.
  final Stream<Shake>? shakes;

  static const _aspectRatio = 0.86; // width / height of the paint box

  @override
  State<EggView> createState() => _EggViewState();
}

class _EggViewState extends State<EggView> with SingleTickerProviderStateMixin {
  static const _shaderAsset = 'shaders/egg.frag';

  static const _breathPeriod = Duration(seconds: 3);
  static const _breathScale = 0.02;

  /// Camera radians per logical pixel dragged.
  static const _dragSensitivity = 0.012;
  static const _maxPitch = 0.9;

  /// Fraction of the spin speed that survives each second after release.
  static const _spinDecayPerSecond = 0.12;
  static const _maxSpinSpeed = 6.0; // radians per second
  static const _spinRestSpeed = 0.02;

  /// How far a tap squashes and rocks the shell, and how long it rings.
  static const _pokeSquash = 0.055;
  static const _pokeRock = 0.07; // radians
  static const _pokeDuration = 1.2; // seconds

  /// A shake should throw the shell around harder than a fingertip does.
  static const _shakeKnockScale = 1.6;
  static const _maxKnockStrength = 2.4;

  ui.FragmentShader? _shader;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  double _breathPhase = 0;
  double _yaw = 0;
  double _pitch = 0;
  double _yawSpeed = 0;
  double _pitchSpeed = 0;

  /// Seconds since the last tap, or infinity when the shell is at rest.
  double _pokeElapsed = double.infinity;
  double _pokeDirection = 0; // -1 knocked from the left, 1 from the right
  double _pokeStrength = 1;

  StreamSubscription<Shake>? _shakeSubscription;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _shakeSubscription = widget.shakes?.listen(_onShake);
    _loadShader();
  }

  @override
  void didUpdateWidget(EggView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakes != oldWidget.shakes) {
      _shakeSubscription?.cancel();
      _shakeSubscription = widget.shakes?.listen(_onShake);
    }
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(_shaderAsset);
      if (!mounted) {
        return;
      }
      setState(() => _shader = program.fragmentShader());
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'oddlet',
          context: ErrorDescription('loading egg shader $_shaderAsset'),
        ),
      );
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (dt <= 0) {
      return;
    }

    setState(() {
      _breathPhase = (_breathPhase + dt / (_breathPeriod.inMilliseconds / 1000)) % 1.0;
      _applySpin(dt);
      _advancePoke(dt);
    });
  }

  /// Free spin after the finger lifts, decaying exponentially.
  void _applySpin(double dt) {
    if (_yawSpeed == 0 && _pitchSpeed == 0) {
      return;
    }

    _rotateBy(_yawSpeed * dt, _pitchSpeed * dt);

    final decay = math.pow(_spinDecayPerSecond, dt).toDouble();
    _yawSpeed *= decay;
    _pitchSpeed *= decay;

    if (_yawSpeed.abs() < _spinRestSpeed) {
      _yawSpeed = 0;
    }
    if (_pitchSpeed.abs() < _spinRestSpeed) {
      _pitchSpeed = 0;
    }
  }

  void _advancePoke(double dt) {
    if (!_pokeElapsed.isFinite) {
      return;
    }
    _pokeElapsed += dt;
    if (_pokeElapsed > _pokeDuration) {
      _pokeElapsed = double.infinity;
    }
  }

  /// Knock the shell so it squashes and rocks away from [direction].
  void _knock({required double direction, required double strength}) {
    setState(() {
      _pokeElapsed = 0;
      _pokeDirection = direction.clamp(-1.0, 1.0);
      _pokeStrength = strength;
    });
  }

  void _onTapDown(TapDownDetails details) {
    final width = widget.height * EggView._aspectRatio;
    _knock(
      direction: (details.localPosition.dx - width / 2) / (width / 2),
      strength: 1,
    );
    HapticFeedback.lightImpact();
  }

  void _onShake(Shake shake) {
    // No haptics here: the device is already moving in the user's hand.
    _knock(
      direction: shake.direction,
      strength: (shake.strength * _shakeKnockScale).clamp(1.0, _maxKnockStrength),
    );
  }

  void _rotateBy(double yawDelta, double pitchDelta) {
    _yaw += yawDelta;
    final pitch = _pitch + pitchDelta;
    _pitch = pitch.clamp(-_maxPitch, _maxPitch);
    if (_pitch != pitch) {
      _pitchSpeed = 0; // stop pushing against the clamp
    }
  }

  void _onPanStart(DragStartDetails details) {
    _yawSpeed = 0;
    _pitchSpeed = 0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _rotateBy(
        -details.delta.dx * _dragSensitivity,
        -details.delta.dy * _dragSensitivity,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    _yawSpeed =
        (-velocity.dx * _dragSensitivity).clamp(-_maxSpinSpeed, _maxSpinSpeed);
    _pitchSpeed =
        (-velocity.dy * _dragSensitivity).clamp(-_maxSpinSpeed, _maxSpinSpeed);
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final size = Size(widget.height * EggView._aspectRatio, widget.height);

    if (shader == null) {
      return SizedBox.fromSize(size: size);
    }

    final scheme = Theme.of(context).colorScheme;
    final breath = 1 + _breathScale * (1 - math.cos(_breathPhase * 2 * math.pi)) / 2;
    final poke = _pokeElapsed.isFinite
        ? pokeAmplitude(_pokeElapsed) * _pokeStrength
        : 0.0;

    return Semantics(
      label: 'Egg',
      hint: 'Tap to touch the egg, drag to look around it',
      child: GestureDetector(
        onTapDown: _onTapDown,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        // The shell sits on its base, so it squashes and rocks about the bottom.
        child: Transform.rotate(
          alignment: Alignment.bottomCenter,
          angle: _pokeRock * poke * _pokeDirection,
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(
              breath * (1 + _pokeSquash * poke),
              breath * (1 - _pokeSquash * poke),
              1,
            ),
            child: CustomPaint(
              size: size,
              painter: _EggPainter(
                shader: shader,
                devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                yaw: _yaw,
                pitch: _pitch,
                appearance: widget.appearance,
                tint: scheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EggPainter extends CustomPainter {
  const _EggPainter({
    required this.shader,
    required this.devicePixelRatio,
    required this.yaw,
    required this.pitch,
    required this.appearance,
    required this.tint,
  });

  final ui.FragmentShader shader;
  final double devicePixelRatio;
  final double yaw;
  final double pitch;
  final EggAppearance appearance;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    // Index order must match the uniform declarations in shaders/egg.frag.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, devicePixelRatio)
      ..setFloat(3, yaw)
      ..setFloat(4, pitch)
      ..setFloat(5, appearance.shell.r)
      ..setFloat(6, appearance.shell.g)
      ..setFloat(7, appearance.shell.b)
      ..setFloat(8, appearance.speckle.r)
      ..setFloat(9, appearance.speckle.g)
      ..setFloat(10, appearance.speckle.b)
      ..setFloat(11, tint.r)
      ..setFloat(12, tint.g)
      ..setFloat(13, tint.b)
      ..setFloat(14, appearance.textureScale)
      ..setFloat(15, appearance.textureContrast)
      ..setFloat(16, appearance.blotchiness)
      ..setFloat(17, appearance.noiseOffset);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_EggPainter oldDelegate) =>
      yaw != oldDelegate.yaw ||
      pitch != oldDelegate.pitch ||
      devicePixelRatio != oldDelegate.devicePixelRatio ||
      appearance != oldDelegate.appearance ||
      tint != oldDelegate.tint;
}
