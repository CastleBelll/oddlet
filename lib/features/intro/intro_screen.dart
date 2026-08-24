import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import 'intro_controller.dart';
import 'typed_line.dart';

/// The opening. Someone types a few lines at you and gets out of the way.
///
/// It sets a mood and explains nothing. A line that hinted at how to get a
/// creature would undo the guessing the whole app is built on.
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  /// The beat between one line landing and the next starting.
  static const _betweenLines = Duration(milliseconds: 650);

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  Timer? _pause;

  /// How many lines have been started. The last one may still be arriving.
  int _reached = 1;
  bool _allTyped = false;
  bool _skipped = false;

  @override
  void dispose() {
    _pause?.cancel();
    super.dispose();
  }

  void _onLineFinished(int index, int total) {
    if (index < total - 1) {
      _pause?.cancel();
      _pause = Timer(IntroScreen._betweenLines, () {
        if (mounted) {
          setState(() => _reached = index + 2);
        }
      });
      return;
    }
    if (!_allTyped && mounted) {
      setState(() => _allTyped = true);
    }
  }

  /// One tap drops the rest of it in at once; the next one leaves.
  void _skipOrFinish(int total) {
    if (!_allTyped) {
      _pause?.cancel();
      setState(() {
        _skipped = true;
        _reached = total;
      });
      return;
    }
    unawaited(ref.read(introSeenProvider.notifier).markSeen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final lines = [l10n.introLine1, l10n.introLine2, l10n.introLine3];

    // Someone who has asked the system for less movement gets the words, not
    // the performance.
    final instant = _skipped || MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: GestureDetector(
        onTap: () => _skipOrFinish(lines.length),
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: oddletVignette),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, line) in lines.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: index < _reached
                          ? TypedLine(
                              // A new key per line, so each starts fresh
                              // rather than inheriting the last one's progress.
                              key: ValueKey(line),
                              text: line,
                              instant: instant,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: scheme.onSurface,
                              ),
                              onFinished: () =>
                                  _onLineFinished(index, lines.length),
                            )
                          : // Keeps the block from growing as lines arrive.
                            Opacity(
                              opacity: 0,
                              child: Text(
                                line,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                    ),
                  const SizedBox(height: 40),
                  AnimatedOpacity(
                    opacity: _allTyped ? 1 : 0,
                    duration: const Duration(milliseconds: 600),
                    child: Text(
                      l10n.introContinue,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
