import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_controller.dart';
import '../egg/daily_egg_controller.dart';
import 'collection_entry.dart';
import 'collection_store.dart';
import 'local_collection_archive.dart';

/// Where this account's collection is kept.
///
/// Watches the account rather than reading it once: linking keeps the same id
/// and so the same collection, but signing into an account someone already had
/// changes the id, and the collection on screen has to change with it.
final collectionStoreProvider = Provider<CollectionStore>((ref) {
  final userId = ref.watch(accountProvider).value?.uid;
  if (userId == null) {
    return const UnsavedCollectionStore();
  }
  return FirestoreCollectionStore(userId);
});

final collectionArchiveProvider = Provider<LocalCollectionArchive>(
  (ref) => LocalCollectionArchive(),
);

final collectionControllerProvider =
    AsyncNotifierProvider<CollectionController, Map<int, CollectionEntry>>(
      CollectionController.new,
    );

/// Everything the user has found, keyed by creature id.
class CollectionController extends AsyncNotifier<Map<int, CollectionEntry>> {
  @override
  Future<Map<int, CollectionEntry>> build() async {
    // Waiting on the account, not just reading it: the store cannot know where
    // to look until sign-in has settled.
    await ref.watch(accountProvider.future);
    final store = ref.watch(collectionStoreProvider);
    final found = await store.load();

    if (store is UnsavedCollectionStore) {
      // Nowhere to move anything to yet. Leave the old records where they are
      // so the next launch with an account can still collect them.
      return found;
    }

    return {..._moveInOldFinds(store, found, await _archived()), ...found};
  }

  Future<Map<int, CollectionEntry>> _archived() =>
      ref.read(collectionArchiveProvider).drain();

  /// Carries over anything found back when the collection lived on the phone.
  ///
  /// Records already on the account win: they are the ones the rules have been
  /// keeping count of, and a lower local count would be refused anyway.
  Map<int, CollectionEntry> _moveInOldFinds(
    CollectionStore store,
    Map<int, CollectionEntry> found,
    Map<int, CollectionEntry> archived,
  ) {
    final moved = <int, CollectionEntry>{};

    for (final entry in archived.entries) {
      if (found.containsKey(entry.key)) {
        continue;
      }
      store.write(entry.value);
      moved[entry.key] = entry.value;
    }

    return moved;
  }

  /// Files a find away.
  ///
  /// Returns whether this filled an empty slot, which is the part of a hatch
  /// the user really cares about.
  Future<bool> record(int species) async {
    // Wait for the stored collection before adding to it. A hatch can land
    // while the load is still in flight, and a load that finishes afterwards
    // would otherwise overwrite the find.
    final found = await future;
    final at = ref.read(clockProvider)();
    final existing = found[species];

    final entry = existing == null
        ? CollectionEntry.firstFind(species, at)
        : existing.foundAgain(at);

    state = AsyncData({...found, species: entry});
    ref.read(collectionStoreProvider).write(entry);

    return existing == null;
  }
}
