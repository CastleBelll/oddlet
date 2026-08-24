import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../creatures/creature_labels.dart';
import '../creatures/creature_view.dart';
import '../rules/creature.dart';

/// What was inside, rising out of the dark the hatch sequence ended on.
class HatchReveal extends StatelessWidget {
  const HatchReveal({
    super.key,
    required this.creature,
    required this.onDismiss,
  });

  static const _creatureHeightRatio = 0.34;
  static const _maxCreatureHeight = 280.0;
  static const _riseDuration = Duration(milliseconds: 900);

  final Creature creature;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final name = creatureName(l10n, creature.id);
    final tier = rarityLabel(l10n, creature.rarity);

    return Semantics(
      label: '$name, $tier',
      button: true,
      child: GestureDetector(
        onTap: onDismiss,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: scheme.surface,
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
                      ExcludeSemantics(
                        child: CreatureView(
                          creatureId: creature.id,
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
                      const SizedBox(height: 56),
                      Text(
                        l10n.revealDismiss,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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
