import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collection_entry.dart';

/// The collection as it used to be kept, on the handset.
///
/// Read once and emptied, so what someone found before the collection moved to
/// their account comes with them. Not a store: nothing is ever written back
/// here, because two copies of a collection is one copy too many.
///
/// TODO(TASK-015): delete this and its key a release or two after everyone has
/// been through it once.
class LocalCollectionArchive {
  static const _key = 'oddlet.collection';

  /// Everything the old store held, removing it as it goes.
  ///
  /// Returns empty when there is nothing left to move, which is the normal
  /// case after the first run.
  Future<Map<String, CollectionEntry>> drain() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_key);
    if (stored == null) {
      return const {};
    }

    final entries = <String, CollectionEntry>{};
    try {
      final decoded = jsonDecode(stored) as Map<String, Object?>;
      for (final record in decoded.entries) {
        try {
          entries[record.key] = CollectionEntry.fromJson(
            record.value! as Map<String, Object?>,
          );
        } catch (error, stack) {
          _report(error, stack, 'moving collection entry ${record.key}');
        }
      }
    } catch (error, stack) {
      _report(error, stack, 'moving the stored collection');
    }

    await preferences.remove(_key);
    return entries;
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
