import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../account/account_controller.dart';
import '../account/account_upgrade_sheet.dart';
import '../creatures/creature_labels.dart';
import '../creatures/creature_view.dart';
import '../rules/creature.dart';
import '../rules/season_01.dart';
import 'collection_controller.dart';
import 'collection_entry.dart';

/// The empty slots are the point: a gap the user can see is what brings them
/// back tomorrow.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  static const _tileSize = 84.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final found = ref.watch(collectionControllerProvider).value ?? const {};

    // An undiscovered secret is not even shown as a slot. Knowing one exists is
    // already a clue, and the secret is the one thing worth keeping quiet.
    final listed = season01Creatures
        .where(
          (creature) =>
              creature.rarity != Rarity.secret ||
              found.containsKey(creature.id),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.collectionTitle,
          style: const TextStyle(letterSpacing: 4),
        ),
        leading: BackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              l10n.collectionProgress(found.length, listed.length),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (ref.watch(accountProvider.notifier).isAnonymous &&
                found.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: _KeepItBanner(),
              ),
            const SizedBox(height: 28),
            for (final rarity in Rarity.values)
              if (listed.any((creature) => creature.rarity == rarity))
                _RaritySection(
                  rarity: rarity,
                  creatures: listed
                      .where((creature) => creature.rarity == rarity)
                      .toList(),
                  found: found,
                ),
          ],
        ),
      ),
    );
  }
}

/// Offered only once there is something to lose. Asking someone to sign in
/// over an empty collection is asking for nothing in return.
class _KeepItBanner extends StatelessWidget {
  const _KeepItBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.accountLocalOnly,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => showAccountUpgradeSheet(context),
              child: Text(l10n.accountConnect),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaritySection extends StatelessWidget {
  const _RaritySection({
    required this.rarity,
    required this.creatures,
    required this.found,
  });

  final Rarity rarity;
  final List<Creature> creatures;
  final Map<String, CollectionEntry> found;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rarityLabel(l10n, rarity),
            style: theme.textTheme.labelMedium?.copyWith(
              color: rarityColor(theme.colorScheme, rarity),
              letterSpacing: 2,
              shadows: rarityGlows(rarity)
                  ? neonGlow(rarityColor(theme.colorScheme, rarity), blur: 12)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final creature in creatures)
                _Slot(creature: creature, entry: found[creature.id]),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.creature, required this.entry});

  final Creature creature;
  final CollectionEntry? entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entry = this.entry;

    if (entry == null) {
      return Semantics(
        label: l10n.collectionUndiscovered,
        child: _SlotFrame(
          child: Text(
            // Not copy: it reads the same in every language.
            '?',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final name = creatureName(l10n, creature.id);

    return Semantics(
      label: '$name, ${l10n.collectionFoundCount(entry.count)}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            _SlotFrame(
              child: CreatureView(
                creature: creature,
                height: CollectionScreen._tileSize * 0.82,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: CollectionScreen._tileSize,
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotFrame extends StatelessWidget {
  const _SlotFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: CollectionScreen._tileSize,
      height: CollectionScreen._tileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
