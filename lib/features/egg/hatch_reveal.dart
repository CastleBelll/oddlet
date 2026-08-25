import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../../ui/oddlet_dialog.dart';
import '../account/account_controller.dart';
import '../share/share_card.dart';
import '../share/share_result.dart';
import '../creatures/creature_appearance.dart';
import '../creatures/creature_labels.dart';
import '../creatures/creature_view.dart';
import '../naming/name_it_sheet.dart';
import '../naming/naming_repository.dart';
import '../naming/species_name.dart';
import '../rules/creature.dart';

/// What was inside, rising out of the dark the hatch sequence ended on.
///
/// Also where a creature gets its name. Naming waits until the hatch has
/// finished playing — the animation is the payoff and must not be interrupted
/// — and is offered here rather than later because this is the moment the
/// finder cares about it.
class HatchReveal extends ConsumerStatefulWidget {
  const HatchReveal({
    super.key,
    required this.creature,
    required this.isNew,
    required this.foundAt,
    required this.onDismiss,
  });

  // Long enough for the creature to land before the words start, short enough
  // that nobody waits for the buttons.
  static const _riseDuration = Duration(milliseconds: 1200);

  final Creature creature;

  /// Whether this find filled an empty slot.
  final bool isNew;

  final DateTime foundAt;

  final VoidCallback onDismiss;

  @override
  ConsumerState<HatchReveal> createState() => _HatchRevealState();
}

class _HatchRevealState extends ConsumerState<HatchReveal> {
  static const _creatureHeightRatio = 0.34;
  static const _maxCreatureHeight = 280.0;

  final _cardKey = GlobalKey();

  /// Which of the season's creatures this is. Two people holding the same
  /// species are holding the same creature, which is what a first discovery
  /// is claimed against.
  int get _species => CreatureAppearance.of(widget.creature).species;

  void _share() => shareCapturedCard(
    cardKey: _cardKey,
    creatureId: widget.creature.id,
  );

  Future<void> _nameIt() async {
    final named = await showNameItSheet(context, species: _species);
    if (named != null && mounted) {
      await showOddletMessage(
        context,
        AppLocalizations.of(context).nameItDone(named),
      );
    }
  }

  /// Leaves the reveal, checking first if a nameless creature is being left
  /// nameless.
  ///
  /// Asked once and only once. The choice cannot be taken back, so it should
  /// not be made by a stray tap; asking twice would be nagging.
  Future<void> _leave() async {
    // hasValue, not value == null: while the lookup is in flight the two are
    // indistinguishable, and asking about naming a creature that already has
    // a name would be nonsense.
    final lookup = ref.read(speciesNameProvider(_species));
    final unnamed =
        lookup.hasValue &&
        lookup.value == null &&
        !ref.read(accountProvider.notifier).isAnonymous;

    if (unnamed) {
      final l10n = AppLocalizations.of(context);
      final passed = await showOddletChoice(
        context,
        title: l10n.namePassTitle,
        message: l10n.namePassBody,
        confirmLabel: l10n.namePassConfirm,
        cancelLabel: l10n.namePassBack,
      );
      if (!mounted) {
        return;
      }
      if (!passed) {
        await _nameIt();
        return;
      }
    }

    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final creature = widget.creature;
    final isNew = widget.isNew;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final lookup = ref.watch(speciesNameProvider(_species));
    final registered = lookup.value;
    // Offered only once the answer is in. Held back while the lookup is in
    // flight, so the button does not appear and then vanish under a thumb
    // already on its way to it.
    final offerNaming = lookup.hasValue && registered == null;
    // A registered name wins over the one shipped with the app: the shipped
    // one is a placeholder for a creature nobody has claimed yet.
    final name = registered?.name ?? creatureName(l10n, creature.id);
    final tier = rarityLabel(l10n, creature.rarity);

    return Stack(
      children: [
        // Drawn underneath and completely covered, so it stays painted and
        // ready to capture without ever being seen.
        Positioned.fill(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: ShareCard.size.width,
              maxWidth: ShareCard.size.width,
              minHeight: ShareCard.size.height,
              maxHeight: ShareCard.size.height,
              child: RepaintBoundary(
                key: _cardKey,
                child: ShareCard(
                  creature: creature,
                  isNew: isNew,
                  foundAt: widget.foundAt,
                ),
              ),
            ),
          ),
        ),
        // Must cover the card completely; anything it leaves uncovered would
        // show a corner of a 1080x1920 card.
        Positioned.fill(
          child: _revealBody(
            context,
            l10n,
            scheme,
            theme,
            name,
            tier,
            registered,
            offerNaming,
          ),
        ),
      ],
    );
  }

  Widget _revealBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    ThemeData theme,
    String name,
    String tier,
    SpeciesName? registered,
    bool offerNaming,
  ) {
    final creature = widget.creature;
    final isNew = widget.isNew;
    final mine =
        registered != null &&
        registered.discovererUid == ref.watch(accountProvider).value?.uid;

    return Semantics(
      label: isNew ? '${l10n.revealNew}, $name, $tier' : '$name, $tier',
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: oddletVignette),
        child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final creatureHeight =
                    (constraints.maxHeight * _creatureHeightRatio).clamp(
                      0.0,
                      _maxCreatureHeight,
                    );

                return _Arrival(
                  glowRadius: creatureHeight * 1.15,
                  creature: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isNew)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            l10n.revealNew,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              letterSpacing: 4,
                              shadows: neonGlow(scheme.primary),
                            ),
                          ),
                        ),
                      ExcludeSemantics(
                        child: CreatureView(
                          creature: creature,
                          height: creatureHeight,
                        ),
                      ),
                    ],
                  ),
                  details: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tier,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: rarityColor(scheme, creature.rarity),
                          letterSpacing: 3,
                          shadows: rarityGlows(creature.rarity)
                              ? neonGlow(rarityColor(scheme, creature.rarity))
                              : null,
                        ),
                      ),
                      if (registered != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          mine
                              ? l10n.nameDiscoveredByYou
                              : l10n.nameDiscoveredBy(
                                  registered.discovererHandle,
                                ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                      if (offerNaming)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FilledButton(
                            onPressed: _nameIt,
                            child: Text(l10n.nameItButton),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(l10n.revealShare),
                      ),
                      const SizedBox(height: 24),
                      // Deliberate rather than "tap anywhere": a near miss on
                      // Share used to dismiss the reveal and take the only
                      // chance to post it with it.
                      TextButton(
                        onPressed: _leave,
                        child: Text(
                          l10n.revealDismiss,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
  }
}

/// Brings the creature in, then the words about it.
///
/// Staged rather than fading the whole screen up at once: the creature is what
/// the last three seconds were for, and a name sliding in beside it while it is
/// still arriving splits the moment in two.
class _Arrival extends StatefulWidget {
  const _Arrival({
    required this.creature,
    required this.details,
    required this.glowRadius,
  });

  final Widget creature;
  final Widget details;

  /// How far the light it came out of reaches.
  final double glowRadius;

  @override
  State<_Arrival> createState() => _ArrivalState();
}

class _ArrivalState extends State<_Arrival> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HatchReveal._riseDuration,
  )..forward();

  // Overshoots and settles. A creature that scales straight to its size looks
  // placed there; one that goes slightly past and comes back has weight.
  late final Animation<double> _grow = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.62, curve: Curves.easeOutBack),
  );

  /// The last of the light from inside the egg, arriving with the creature and
  /// gone a moment later.
  late final Animation<double> _flare = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
  );

  late final Animation<double> _details = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.42, 1.0, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final grow = _grow.value;
        // Up and back down across the interval, so the flare peaks with the
        // creature rather than lingering behind it.
        final flare = math.sin(math.pi * _flare.value);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              // The light reaches past the creature. Positioned rather than
              // sized, so it paints outside the stack without taking any room:
              // as a laid-out child it made the column taller than the screen.
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  left: -widget.glowRadius,
                  right: -widget.glowRadius,
                  top: -widget.glowRadius,
                  bottom: -widget.glowRadius,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (flare * 0.85).clamp(0.0, 1.0),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              OddletColors.hatchLight,
                              Color(0x00000000),
                            ],
                            stops: [0.0, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: grow.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.72 + 0.28 * grow,
                    child: widget.creature,
                  ),
                ),
              ],
            ),
            Opacity(
              opacity: _details.value,
              child: Transform.translate(
                offset: Offset(0, (1 - _details.value) * 22),
                child: widget.details,
              ),
            ),
          ],
        );
      },
    );
  }
}
