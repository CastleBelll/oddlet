import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collection_entry.dart';

/// Keeps the collection on the device.
///
/// TODO(TASK-015): the collection belongs to the account, not the handset.
/// Move it to Firestore, whose offline cache already does this job, and delete
/// this class rather than running both.
class CollectionStore {
  static const _key = 'oddlet.collection';

  /// Everything found so far, keyed by creature id.
  ///
  /// Unreadable records are dropped one at a time: one bad entry must not cost
  /// the user the rest of their collection.
  Future<Map<String, CollectionEntry>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_key);
    if (stored == null) {
      return const {};
    }

    try {
      final decoded = jsonDecode(stored) as Map<String, Object?>;
      final entries = <String, CollectionEntry>{};

      for (final record in decoded.entries) {
        try {
          entries[record.key] = CollectionEntry.fromJson(
            record.value! as Map<String, Object?>,
          );
        } catch (error, stack) {
          _report(error, stack, 'reading collection entry ${record.key}');
        }
      }

      return entries;
    } catch (error, stack) {
      _report(error, stack, 'reading the stored collection');
      await preferences.remove(_key);
      return const {};
    }
  }

  Future<void> save(Map<String, CollectionEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(entries.map((id, entry) => MapEntry(id, entry.toJson()))),
    );
  }

  void _report(Object error, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'oddlet',
        context: ErrorDescription(context),
      ),
    );
  }
}
