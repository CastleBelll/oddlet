import 'dart:async';

import 'package:flutter/material.dart';

/// One line arriving the way someone types it.
///
/// Advances by grapheme cluster rather than by code unit, so a Korean syllable
/// lands as a finished character instead of assembling from its parts, and an
/// emoji is never cut in half.
class TypedLine extends StatefulWidget {
  const TypedLine({
    super.key,
    required this.text,
    required this.style,
    required this.onFinished,
    this.instant = false,
  });

  static const perCharacter = Duration(milliseconds: 55);

  final String text;
  final TextStyle? style;
  final VoidCallback onFinished;

  /// Skips straight to the whole line. Set when the user has asked to get on
  /// with it, or when the system asks for reduced motion.
  final bool instant;

  @override
  State<TypedLine> createState() => _TypedLineState();
}

class _TypedLineState extends State<TypedLine> {
  Timer? _timer;
  int _typed = 0;

  int get _length => widget.text.characters.length;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(TypedLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.instant && !oldWidget.instant) {
      _finish();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (widget.instant) {
      // After this frame: the parent is mid build, and finishing now would
      // ask it to rebuild while it is still building.
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return;
    }
    _timer = Timer.periodic(TypedLine.perCharacter, (timer) {
      if (_typed >= _length) {
        _finish();
        return;
      }
      setState(() => _typed++);
    });
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) {
      return;
    }
    if (_typed != _length) {
      setState(() => _typed = _length);
    }
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final done = _typed >= _length;
    final shown = widget.text.characters.take(_typed).toString();

    return Semantics(
      // Read in full from the start. Watching it arrive is the point for
      // someone who can see it, and no use to anyone who cannot.
      label: widget.text,
      child: ExcludeSemantics(
        child: Stack(
          children: [
            // Holds the line's final size so nothing reflows as it fills in.
            Opacity(opacity: 0, child: Text(widget.text, style: widget.style)),
            Text(done ? shown : '$shown▌', style: widget.style),
          ],
        ),
      ),
    );
  }
}
