import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../rules/creature.dart';
import 'creature_appearance.dart';

/// Draws one creature the same way the egg is drawn: a shader rather than an
/// image, so there is nothing to author while the art direction is still open.
class CreatureView extends StatefulWidget {
  const CreatureView({
    super.key,
    required this.creature,
    required this.height,
  });

  final Creature creature;
  final double height;

  @override
  State<CreatureView> createState() => _CreatureViewState();
}

class _CreatureViewState extends State<CreatureView> {
  static const _shaderAsset = 'shaders/creature.frag';

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
          context: ErrorDescription('loading creature shader $_shaderAsset'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final size = Size.square(widget.height);

    if (shader == null) {
      return SizedBox.fromSize(size: size);
    }

    return CustomPaint(
      size: size,
      painter: _CreaturePainter(
        shader: shader,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        appearance: CreatureAppearance.of(widget.creature),
        tint: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _CreaturePainter extends CustomPainter {
  const _CreaturePainter({
    required this.shader,
    required this.devicePixelRatio,
    required this.appearance,
    required this.tint,
  });

  final ui.FragmentShader shader;
  final double devicePixelRatio;
  final CreatureAppearance appearance;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    // Index order must match the uniforms in shaders/creature.frag.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, devicePixelRatio)
      ..setFloat(3, appearance.body.r)
      ..setFloat(4, appearance.body.g)
      ..setFloat(5, appearance.body.b)
      ..setFloat(6, appearance.belly.r)
      ..setFloat(7, appearance.belly.g)
      ..setFloat(8, appearance.belly.b)
      ..setFloat(9, tint.r)
      ..setFloat(10, tint.g)
      ..setFloat(11, tint.b)
      ..setFloat(12, appearance.squash)
      ..setFloat(13, appearance.eyeSpacing)
      ..setFloat(14, appearance.eyeSize)
      ..setFloat(15, appearance.eyeCount.toDouble())
      ..setFloat(16, appearance.earLength)
      ..setFloat(17, appearance.earSpread)
      ..setFloat(18, appearance.earRadius)
      ..setFloat(19, appearance.lumpHeight)
      ..setFloat(20, appearance.lumpRadius)
      ..setFloat(21, appearance.bumpiness)
      ..setFloat(22, appearance.glow);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_CreaturePainter oldDelegate) =>
      appearance != oldDelegate.appearance ||
      devicePixelRatio != oldDelegate.devicePixelRatio ||
      tint != oldDelegate.tint;
}
