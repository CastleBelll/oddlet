import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../account/account_controller.dart';
import '../account/account_upgrade_sheet.dart';
import '../creatures/creature_labels.dart';
import '../creatures/creature_view.dart';
import '../naming/naming_repository.dart';
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

    // One slot per species, not per rule: a species is what has a look, a
    // name and a first discoverer, so it is what a slot can stand for.
    //
    // An undiscovered secret is not even shown as a slot. Knowing one exists is
    // already a clue, and the secret is the one thing worth keeping quiet.
    final listed = {
      for (final rarity in Rarity.values)
        rarity: [
          for (final species in season01SpeciesIn(rarity))
            if (rarity != Rarity.secret || found.containsKey(species)) species,
        ],
    };

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
              l10n.collectionProgress(found.length, season01SpeciesCount),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // Watches the value, not the notifier: watching the notifier does
            // not rebuild when sign-in settles, and the banner would go on
            // asking for an account the user had just connected.
            if ((ref.watch(accountProvider).value?.isAnonymous ?? true) &&
                found.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: _KeepItBanner(),
              ),
            const SizedBox(height: 28),
            for (final rarity in Rarity.values)
              if (listed[rarity]!.isNotEmpty)
                _RaritySection(
                  rarity: rarity,
                  species: listed[rarity]!,
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
    required this.species,
    required this.found,
  });

  final Rarity rarity;
  final List<int> species;
  final Map<int, CollectionEntry> found;

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
              for (final id in species)
                _Slot(species: id, rarity: rarity, entry: found[id]),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slot extends ConsumerWidget {
  const _Slot({
    required this.species,
    required this.rarity,
    required this.entry,
  });

  final int species;
  final Rarity rarity;
  final CollectionEntry? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // Nothing has a name until somebody gives it one, so a species nobody has
    // claimed is shown by its number. A made-up name in the meantime would be
    // the app taking the one thing the finder gets to do.
    final registered = ref.watch(speciesNameProvider(species)).value;
    final name = registered?.name ?? '#$species';

    return Semantics(
      label: '$name, ${l10n.collectionFoundCount(entry.count)}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            _SlotFrame(
              child: CreatureView(
                species: species,
                rarity: rarity,
                height: CollectionScreen._tileSize * 0.82,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: CollectionScreen._tileSize,
              child: Column(
                children: [
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (registered != null)
                    Text(
                      registered.discovererUid ==
                              ref.watch(accountProvider).value?.uid
                          ? l10n.nameDiscoveredByYou
                          : l10n.nameDiscoveredBy(registered.discovererHandle),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
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
