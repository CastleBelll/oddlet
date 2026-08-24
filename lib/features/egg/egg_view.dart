import 'package:flutter/material.dart';

/// The egg the user keeps for the day, with a subtle idle breathing motion.
///
/// TODO: replace the painted shape with the Season 01 pixel art sprite.
class EggView extends StatefulWidget {
  const EggView({super.key, required this.height});

  final double height;

  @override
  State<EggView> createState() => _EggViewState();
}

class _EggViewState extends State<EggView> with SingleTickerProviderStateMixin {
  static const _breathPeriod = Duration(seconds: 3);
  static const _breathScale = 0.02;
  static const _breathTilt = 0.014; // radians
  static const _eggAspectRatio = 0.76; // width / height

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _breathPeriod,
  )..repeat(reverse: true);

  late final Animation<double> _breath = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Egg',
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, child) {
          final t = _breath.value;
          return Transform.rotate(
            angle: (t - 0.5) * 2 * _breathTilt,
            child: Transform.scale(scale: 1 + t * _breathScale, child: child),
          );
        },
        child: CustomPaint(
          size: Size(widget.height * _eggAspectRatio, widget.height),
          painter: _EggPainter(
            base: scheme.surfaceContainerHighest,
            highlight:
                Color.lerp(scheme.surfaceContainerHighest, Colors.white, 0.28)!,
            shadow: scheme.shadow,
          ),
        ),
      ),
    );
  }
}

class _EggPainter extends CustomPainter {
  const _EggPainter({
    required this.base,
    required this.highlight,
    required this.shadow,
  });

  final Color base;
  final Color highlight;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _eggPath(size);

    canvas.drawShadow(path, shadow, 14, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.0,
          colors: [highlight, base],
        ).createShader(Offset.zero & size),
    );
  }

  /// Egg silhouette: a tall narrow dome on top, a rounder belly below.
  Path _eggPath(Size size) {
    final w = size.width;
    final h = size.height;
    final belly = h * 0.62; // vertical position of the widest point

    return Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w * 0.74, 0, w, belly * 0.46, w, belly)
      ..cubicTo(w, h * 0.87, w * 0.79, h, w / 2, h)
      ..cubicTo(w * 0.21, h, 0, h * 0.87, 0, belly)
      ..cubicTo(0, belly * 0.46, w * 0.26, 0, w / 2, 0)
      ..close();
  }

  @override
  bool shouldRepaint(_EggPainter oldDelegate) =>
      base != oldDelegate.base ||
      highlight != oldDelegate.highlight ||
      shadow != oldDelegate.shadow;
}
