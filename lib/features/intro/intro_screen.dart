import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import 'intro_controller.dart';

/// The opening. Lines surface one at a time out of the dark.
///
/// It sets a mood and explains nothing. A line that hinted at how to get a
/// creature would undo the guessing the whole app is built on.
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  static const _lineInterval = Duration(milliseconds: 2200);
  static const _fadeIn = Duration(milliseconds: 1400);

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  Timer? _timer;
  int _shown = 0;
  int _lineCount = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startIfNeeded(int lineCount) {
    if (_lineCount != 0) {
      return;
    }
    _lineCount = lineCount;
    _timer = Timer.periodic(IntroScreen._lineInterval, (timer) {
      if (_shown >= _lineCount) {
        timer.cancel();
        return;
      }
      setState(() => _shown++);
    });
  }

  /// One tap brings the rest of it up; the next one leaves.
  void _skipOrFinish() {
    if (_shown < _lineCount) {
      setState(() => _shown = _lineCount);
      return;
    }
    _timer?.cancel();
    unawaited(ref.read(introSeenProvider.notifier).markSeen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final lines = [l10n.introLine1, l10n.introLine2, l10n.introLine3];
    _startIfNeeded(lines.length);

    final allShown = _shown >= lines.length;

    return Scaffold(
      body: GestureDetector(
        onTap: _skipOrFinish,
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
                      child: AnimatedOpacity(
                        // A screen reader reads all of it at once. The waiting
                        // is the mood, not the message.
                        opacity: index < _shown ? 1 : 0,
                        duration: IntroScreen._fadeIn,
                        curve: Curves.easeOut,
                        child: Text(
                          line,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                  AnimatedOpacity(
                    opacity: allShown ? 1 : 0,
                    duration: IntroScreen._fadeIn,
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
