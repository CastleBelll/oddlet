import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../share/share_card.dart';
import '../share/share_result.dart';
import '../creatures/creature_labels.dart';
import '../creatures/creature_view.dart';
import '../rules/creature.dart';

/// What was inside, rising out of the dark the hatch sequence ended on.
class HatchReveal extends StatefulWidget {
  const HatchReveal({
    super.key,
    required this.creature,
    required this.isNew,
    required this.foundAt,
    required this.onDismiss,
  });

  static const _riseDuration = Duration(milliseconds: 900);

  final Creature creature;

  /// Whether this find filled an empty slot.
  final bool isNew;

  final DateTime foundAt;

  final VoidCallback onDismiss;

  @override
  State<HatchReveal> createState() => _HatchRevealState();
}

class _HatchRevealState extends State<HatchReveal> {
  static const _creatureHeightRatio = 0.34;
  static const _maxCreatureHeight = 280.0;

  final _cardKey = GlobalKey();

  void _share() => shareCapturedCard(
    cardKey: _cardKey,
    creatureId: widget.creature.id,
  );

  @override
  Widget build(BuildContext context) {
    final creature = widget.creature;
    final isNew = widget.isNew;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final name = creatureName(l10n, creature.id);
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
          child: _revealBody(context, l10n, scheme, theme, name, tier),
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
  ) {
    final creature = widget.creature;
    final isNew = widget.isNew;

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

                return _RisesIntoView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isNew)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            l10n.revealNew,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ExcludeSemantics(
                        child: CreatureView(
                          creature: creature,
                          height: creatureHeight,
                        ),
                      ),
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
                        ),
                      ),
                      const SizedBox(height: 40),
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
                        onPressed: widget.onDismiss,
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

/// Fades and lifts its child once, on first build.
class _RisesIntoView extends StatefulWidget {
  const _RisesIntoView({required this.child});

  final Widget child;

  @override
  State<_RisesIntoView> createState() => _RisesIntoViewState();
}

class _RisesIntoViewState extends State<_RisesIntoView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HatchReveal._riseDuration,
  )..forward();

  late final Animation<double> _entrance = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) => Opacity(
        opacity: _entrance.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _entrance.value) * 28),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
