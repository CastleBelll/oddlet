import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../egg/daily_egg_controller.dart';
import 'collection_entry.dart';
import 'collection_store.dart';

final collectionStoreProvider = Provider<CollectionStore>(
  (ref) => CollectionStore(),
);

final collectionControllerProvider =
    AsyncNotifierProvider<CollectionController, Map<String, CollectionEntry>>(
      CollectionController.new,
    );

/// Everything the user has found, keyed by creature id.
class CollectionController extends AsyncNotifier<Map<String, CollectionEntry>> {
  @override
  Future<Map<String, CollectionEntry>> build() =>
      ref.read(collectionStoreProvider).load();

  /// Files a find away.
  ///
  /// Returns whether this filled an empty slot, which is the part of a hatch
  /// the user really cares about.
  Future<bool> record(String creatureId) async {
    // Wait for the stored collection before adding to it. A hatch can land
    // while the load is still in flight, and a load that finishes afterwards
    // would otherwise overwrite the find.
    final found = await future;
    final at = ref.read(clockProvider)();
    final existing = found[creatureId];

    final entry = existing == null
        ? CollectionEntry.firstFind(creatureId, at)
        : existing.foundAgain(at);

    final updated = {...found, creatureId: entry};
    state = AsyncData(updated);

    // Rare enough to be worth writing straight away, unlike a tap.
    await ref.read(collectionStoreProvider).save(updated);

    return existing == null;
  }
}
