import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../creatures/creature_labels.dart';
import '../creatures/creature_view.dart';
import '../rules/creature.dart';

/// The picture someone posts.
///
/// It carries what was found and nothing about how. The whole point of the
/// viral loop is that whoever sees it has to ask, so a card that answers the
/// question would kill the conversation it exists to start.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.creature,
    required this.isNew,
    required this.foundAt,
  });

  /// Portrait, for the places these get posted.
  static const size = Size(1080, 1920);

  /// Where someone who sees the card can go. Correct before release and
  /// dead until then, which beats inventing a domain nobody owns.
  static const storeLink =
      'play.google.com/store/apps/details?id=com.castlebell.oddlet';

  final Creature creature;
  final bool isNew;
  final DateTime foundAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();

    final accent = rarityColor(scheme, creature.rarity);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The rarer the find, the more the card itself is worth posting.
          // A common gets a plain dark card; the top tiers are lit from behind
          // by their own colour.
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 0.9,
            colors: [
              Color.lerp(scheme.surface, accent, _accentLift(creature.rarity))!,
              scheme.surface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(96),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              if (isNew)
                Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Text(
                    l10n.revealNew,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 56,
                      letterSpacing: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              CreatureView(creature: creature, height: 620),
              const SizedBox(height: 96),
              Text(
                creatureName(l10n, creature.id),
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurface, fontSize: 92),
              ),
              const SizedBox(height: 32),
              Text(
                rarityLabel(l10n, creature.rarity),
                style: TextStyle(
                  color: rarityColor(scheme, creature.rarity),
                  fontSize: 48,
                  letterSpacing: 12,
                ),
              ),
              const Spacer(),
              Text(
                l10n.shareTagline,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurface, fontSize: 46),
              ),
              const SizedBox(height: 56),
              Text(
                DateFormat.yMMMd(locale).format(foundAt),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 34),
              ),
              const SizedBox(height: 24),
              Text(
                // The brand mark, not copy.
                'ODDLET',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 44,
                  letterSpacing: 20,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                storeLink,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                  fontSize: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// How far the card's own colour is pulled toward the tier's.
  static double _accentLift(Rarity rarity) => switch (rarity) {
    Rarity.common => 0.04,
    Rarity.uncommon => 0.09,
    Rarity.rare => 0.14,
    Rarity.epic => 0.20,
    Rarity.legendary => 0.28,
    Rarity.secret => 0.34,
  };
}
