import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The egg the user keeps for the day.
///
/// Rendered in 3D by a raymarching fragment shader, so it takes real lighting
/// and the user can drag to orbit the camera around it.
class EggView extends StatefulWidget {
  const EggView({super.key, required this.height});

  final double height;

  static const _aspectRatio = 0.8; // width / height of the paint box

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

  ui.FragmentShader? _shader;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  double _breathPhase = 0;
  double _yaw = 0;
  double _pitch = 0;
  double _yawSpeed = 0;
  double _pitchSpeed = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadShader();
  }

  @override
  void dispose() {
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

    return Semantics(
      label: 'Egg',
      hint: 'Drag to look around the egg',
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Transform.scale(
          scale: breath,
          child: CustomPaint(
            size: size,
            painter: _EggPainter(
              shader: shader,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              yaw: _yaw,
              pitch: _pitch,
              // The dark scheme surface is near black; lift it so the shell
              // still reads as a lit object.
              base: Color.lerp(
                scheme.surfaceContainerHighest,
                scheme.onSurface,
                0.42,
              )!,
              tint: scheme.primary,
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
    required this.base,
    required this.tint,
  });

  final ui.FragmentShader shader;
  final double devicePixelRatio;
  final double yaw;
  final double pitch;
  final Color base;
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
      ..setFloat(5, base.r)
      ..setFloat(6, base.g)
      ..setFloat(7, base.b)
      ..setFloat(8, tint.r)
      ..setFloat(9, tint.g)
      ..setFloat(10, tint.b);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_EggPainter oldDelegate) =>
      yaw != oldDelegate.yaw ||
      pitch != oldDelegate.pitch ||
      devicePixelRatio != oldDelegate.devicePixelRatio ||
      base != oldDelegate.base ||
      tint != oldDelegate.tint;
}
