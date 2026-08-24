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

  final Creature creature;
  final bool isNew;
  final DateTime foundAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();

    return SizedBox(
      width: size.width,
      height: size.height,
      child: ColoredBox(
        color: scheme.surface,
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
                DateFormat.yMMMd(locale).format(foundAt),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 40),
              ),
              const SizedBox(height: 28),
              Text(
                // The brand mark, not copy.
                'ODDLET',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 44,
                  letterSpacing: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
