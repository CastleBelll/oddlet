import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../rules/creature.dart';

/// Placeholder for a creature with no name in the ARB files. A creature that
/// reaches this was added without its copy; the test suite fails on it, so it
/// should never ship.
const missingCreatureName = '???';

/// Maps a creature id to its localized name.
///
/// ARB keys cannot be built at runtime, so the mapping is written out. It is a
/// lookup rather than logic: nothing here decides anything.
String creatureName(AppLocalizations l10n, String id) => switch (id) {
  'plain_chick' => l10n.creaturePlainChick,
  'sleepy_chick' => l10n.creatureSleepyChick,
  'dizzy_chick' => l10n.creatureDizzyChick,
  'angry_chick' => l10n.creatureAngryChick,
  'ghost_chick' => l10n.creatureGhostChick,
  'static_chick' => l10n.creatureStaticChick,
  'storm_chick' => l10n.creatureStormChick,
  'dawn_runner' => l10n.creatureDawnRunner,
  'the_quiet_one' => l10n.creatureTheQuietOne,
  _ => missingCreatureName,
};

String rarityLabel(AppLocalizations l10n, Rarity rarity) => switch (rarity) {
  Rarity.common => l10n.rarityCommon,
  Rarity.uncommon => l10n.rarityUncommon,
  Rarity.rare => l10n.rarityRare,
  Rarity.epic => l10n.rarityEpic,
  Rarity.legendary => l10n.rarityLegendary,
  Rarity.secret => l10n.raritySecret,
};

/// Rarity is never carried by colour alone: the tier is always spelled out
/// beside it, so this only has to reinforce, never inform.
Color rarityColor(ColorScheme scheme, Rarity rarity) => switch (rarity) {
  // Common stays unlit on purpose. If every tier glowed, the glow would stop
  // meaning anything.
  Rarity.common => scheme.onSurfaceVariant,
  Rarity.uncommon => const Color(0xFF4DFFA6),
  Rarity.rare => const Color(0xFF4DD4FF),
  Rarity.epic => const Color(0xFFC77DFF),
  Rarity.legendary => const Color(0xFFFFD24D),
  Rarity.secret => const Color(0xFFFF4D9D),
};

/// Whether this tier is worth lighting up.
bool rarityGlows(Rarity rarity) => rarity != Rarity.common;
