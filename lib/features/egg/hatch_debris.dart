import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The broken shell, drawn over everything rather than inside the egg.
///
/// The egg is painted in a box only a little larger than itself, so a piece
/// thrown clear of it used to be cut off at the edge of that box. This layer is
/// the whole screen, and it is told how tall the egg's own box is, so a piece
/// leaves from exactly where the egg is at whatever angle it has been turned
/// to.
class HatchDebris extends StatefulWidget {
  const HatchDebris({
    super.key,
    required this.crack,
    required this.yaw,
    required this.pitch,
    required this.shell,
    required this.glow,
    required this.eggHeight,
  });

  static const _shaderAsset = 'shaders/shards.frag';

  /// 0 while the shell is whole, 1 once it has opened.
  final double crack;

  /// The camera, shared with the egg rather than worked out again here: a
  /// piece with a camera of its own would slide off the shell the moment the
  /// user turned it.
  final double yaw;
  final double pitch;

  final Color shell;
  final Color glow;

  /// How tall the egg's own paint box is, in logical pixels. This layer is
  /// bigger, and normalising by its own height instead would shrink the world
  /// and launch the pieces from the wrong place.
  final double eggHeight;

  @override
  State<HatchDebris> createState() => _HatchDebrisState();
}

class _HatchDebrisState extends State<HatchDebris> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        HatchDebris._shaderAsset,
      );
      if (!mounted) {
        return;
      }
      setState(() => _shader = program.fragmentShader());
    } catch (error, stack) {
      // The hatch still plays without its debris. Losing the shell pieces
      // looks worse; it is not a reason to take the moment the app exists for
      // off the screen.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'oddlet',
          context: ErrorDescription('loading the debris shader'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null || widget.crack <= 0) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _DebrisPainter(
        shader: shader,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        crack: widget.crack,
        yaw: widget.yaw,
        pitch: widget.pitch,
        shell: widget.shell,
        glow: widget.glow,
        eggHeight: widget.eggHeight,
      ),
    );
  }
}

class _DebrisPainter extends CustomPainter {
  const _DebrisPainter({
    required this.shader,
    required this.devicePixelRatio,
    required this.crack,
    required this.yaw,
    required this.pitch,
    required this.shell,
    required this.glow,
    required this.eggHeight,
  });

  final ui.FragmentShader shader;
  final double devicePixelRatio;
  final double crack;
  final double yaw;
  final double pitch;
  final Color shell;
  final Color glow;
  final double eggHeight;

  @override
  void paint(Canvas canvas, Size size) {
    // Index order must match the uniforms in shaders/shards.frag. Inserting one
    // in the middle silently shifts every value after it.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, devicePixelRatio)
      ..setFloat(3, eggHeight)
      ..setFloat(4, yaw)
      ..setFloat(5, pitch)
      ..setFloat(6, crack)
      ..setFloat(7, shell.r)
      ..setFloat(8, shell.g)
      ..setFloat(9, shell.b)
      ..setFloat(10, glow.r)
      ..setFloat(11, glow.g)
      ..setFloat(12, glow.b);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_DebrisPainter oldDelegate) =>
      crack != oldDelegate.crack ||
      yaw != oldDelegate.yaw ||
      pitch != oldDelegate.pitch ||
      shell != oldDelegate.shell ||
      glow != oldDelegate.glow ||
      eggHeight != oldDelegate.eggHeight ||
      devicePixelRatio != oldDelegate.devicePixelRatio;
}
