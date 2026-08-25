import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../collection/collection_controller.dart';
import '../collection/collection_screen.dart';
import '../rules/creature.dart';
import '../rules/rule_engine.dart';
import '../rules/season_01.dart';
import 'daily_egg_controller.dart';
import 'egg_appearance.dart';
import 'egg_view.dart';
import 'hatch_reveal.dart';
import 'hatch_sequence.dart';
import 'shake_detector.dart';
import '../../theme.dart';

/// Main screen of the app: the egg, and as little else as possible.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.shakeDetector});

  /// Injectable so tests and tools can drive the egg without real hardware.
  final ShakeDetector? shakeDetector;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _eggHeightRatio = 0.42;
  static const _maxEggHeight = 320.0;

  late final ShakeDetector _shakeDetector;
  late final AppLifecycleListener _lifecycle;
  late final AnimationController _hatch;
  StreamSubscription<Shake>? _shakeCounter;
  HatchStage? _lastStage;

  late final RuleEngine _rules = RuleEngine(season01Creatures);

  /// What came out, or null while the egg is still whole.
  /// From the moment the egg starts giving way until the reveal is gone.
  ///
  /// Not the animation controller's own `isAnimating`: that turns false on the
  /// frame the sequence ends, which is several frames before the reveal is
  /// ready, and the egg would sit there whole again in between.
  bool _opening = false;

  Hatchling? _hatched;

  /// Whether that find filled an empty slot.
  bool _hatchedIsNew = false;
  DateTime _hatchedAt = DateTime(2026);

  @override
  void initState() {
    super.initState();

    _shakeDetector = widget.shakeDetector ?? ShakeDetector();
    _shakeDetector.start();
    _shakeCounter = _shakeDetector.shakes.listen(
      (_) => ref.read(dailyEggControllerProvider.notifier).recordShake(),
    );

    _hatch = AnimationController(vsync: this, duration: hatchDuration)
      ..addListener(_onHatchTick)
      ..addStatusListener(_onHatchStatus);

    // Counts are batched before they reach the disk, so write them out before
    // the app can be killed in the background.
    _lifecycle = AppLifecycleListener(
      onPause: () =>
          unawaited(ref.read(dailyEggControllerProvider.notifier).flush()),
    );
  }

  /// Each stage of the shell giving way gets its own knock in the hand.
  void _onHatchTick() {
    final stage = hatchStageAt(_hatch.value);
    if (stage != _lastStage) {
      _lastStage = stage;
      switch (stage) {
        case HatchStage.cracking:
          HapticFeedback.mediumImpact();
        case HatchStage.breaking:
          HapticFeedback.heavyImpact();
        case HatchStage.trembling:
        case HatchStage.blackout:
        case HatchStage.done:
          break;
      }
    }
    setState(() {});
  }

  void _onHatchStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }

    final egg = ref.read(dailyEggControllerProvider).value;
    if (egg == null) {
      setState(_closeHatch);
      return;
    }

    // The rules see only what the user actually did.
    final result = _rules.select(
      HatchContext(
        touchCount: egg.touchCount,
        shakeCount: egg.shakeCount,
        hatchedAt: ref.read(clockProvider)(),
      ),
    );

    // The shell is left where the sequence ended it — open, and blacked out —
    // until the reveal is over it. Resetting here put a whole undamaged egg
    // back on screen for the frames it takes to file the find away.
    unawaited(_fileResult(result));
  }

  Future<void> _fileResult(Hatchling result) async {
    final isNew = await ref
        .read(collectionControllerProvider.notifier)
        .record(result.species);
    // The daily egg only has to remember that today's is spent and what it
    // turned into; the species is that answer now.
    await ref
        .read(dailyEggControllerProvider.notifier)
        .recordHatch('${result.species}');

    if (!mounted) {
      return;
    }
    setState(() {
      _hatched = result;
      _hatchedIsNew = isNew;
      _hatchedAt = ref.read(clockProvider)();
    });
  }

  void _dismissReveal() => setState(() {
    _hatched = null;
    _closeHatch();
  });

  /// Debug builds only: waiting a day between tries makes the loop slow to
  /// work on.
  void _resetEgg() {
    setState(() {
      _hatched = null;
      _closeHatch();
    });
    unawaited(ref.read(dailyEggControllerProvider.notifier).resetToday());
  }

  void _openCollection() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const CollectionScreen()),
  );

  void _beginHatch() {
    if (_opening) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _opening = true);
    _hatch.forward(from: 0);
  }

  /// Puts the whole egg back, once there is no longer a reveal over it.
  void _closeHatch() {
    _lastStage = null;
    _opening = false;
    _hatch.reset();
  }

  @override
  void dispose() {
    _hatch.dispose();
    _lifecycle.dispose();
    _shakeCounter?.cancel();
    _shakeDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final egg = ref.watch(dailyEggControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The egg sits in a pool of light rather than on a flat page.
          const DecoratedBox(
            decoration: BoxDecoration(gradient: oddletVignette),
          ),
          SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final eggHeight = math.min(
              constraints.maxHeight * _eggHeightRatio,
              _maxEggHeight,
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      SizedBox(width: kDebugMode ? 96 : 48),
                      const Expanded(child: Center(child: _Wordmark())),
                      if (kDebugMode)
                        IconButton(
                          onPressed: _resetEgg,
                          icon: const Icon(Icons.refresh_rounded),
                          // Debug affordance, never seen by a user, so its
                          // label stays out of the translation files.
                          tooltip: 'Reset the egg',
                        ),
                      IconButton(
                        onPressed: _openCollection,
                        icon: const Icon(Icons.grid_view_rounded),
                        tooltip: AppLocalizations.of(context).collectionOpen,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: egg.hasValue && egg.requireValue.isHatched
                        ? const _SpentEgg()
                        : egg.hasValue
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Egg(
                                height: eggHeight,
                                day: egg.requireValue.day,
                                shakes: _shakeDetector.shakes,
                                hatchProgress: _opening ? _hatch.value : null,
                                onHatchRequested: _beginHatch,
                              ),
                              const SizedBox(height: 36),
                              // The one instruction in the app. Without it
                              // there is no way to find out that a long press
                              // is what opens the egg.
                              AnimatedOpacity(
                                opacity: _opening ? 0 : 1,
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  AppLocalizations.of(context).eggHoldToOpen,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : SizedBox(height: eggHeight),
                  ),
                ),
              ],
            );
              },
            ),
          ),
          if (_opening) _HatchOverlay(progress: _hatch.value),
          if (_hatched case final creature?)
            HatchReveal(
              hatchling: creature,
              isNew: _hatchedIsNew,
              foundAt: _hatchedAt,
              onDismiss: _dismissReveal,
            ),
        ],
      ),
    );
  }
}

/// The flash of the shell giving way, and the dark the reveal opens out of.
class _HatchOverlay extends StatelessWidget {
  const _HatchOverlay({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: blackoutAt(progress),
            child: const ColoredBox(color: Colors.black),
          ),
          Opacity(
            opacity: flashAt(progress),
            child: const ColoredBox(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Egg extends ConsumerWidget {
  const _Egg({
    required this.height,
    required this.day,
    required this.shakes,
    required this.hatchProgress,
    required this.onHatchRequested,
  });

  final double height;
  final DateTime day;
  final Stream<Shake> shakes;
  final double? hatchProgress;
  final VoidCallback onHatchRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EggView(
      height: height,
      // Derived from the egg's own day, so crossing midnight with the app open
      // changes the shell along with the egg.
      appearance: EggAppearance.forDay(day),
      shakes: shakes,
      onTouch: ref.read(dailyEggControllerProvider.notifier).recordTouch,
      hatchProgress: hatchProgress,
      onHatchRequested: onHatchRequested,
    );
  }
}

/// Where the egg was, once today's has been opened.
class _SpentEgg extends StatelessWidget {
  const _SpentEgg();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        AppLocalizations.of(context).homeNextEgg,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Text(
      // The brand mark, not copy: it reads the same in every language.
      'ODDLET',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: scheme.onSurfaceVariant,
        letterSpacing: 6,
      ),
    );
  }
}
