import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'collection_entry.dart';

/// Where a collection lives.
///
/// An interface only because a test needs a collection without a network; the
/// app has one implementation.
abstract class CollectionStore {
  Future<Map<String, CollectionEntry>> load();

  /// Files one find away.
  ///
  /// Deliberately not a [Future]. A Firestore write made offline is saved to
  /// disk and replayed later, but its future does not complete until it has
  /// reached the server — awaiting it would hang a hatch on a network the user
  /// may not have.
  void write(CollectionEntry entry);
}

/// The collection as the account owns it.
///
/// One document per creature under `users/{uid}/collection`, which is the
/// shape firestore.rules guards: a find count that only grows and a first find
/// that never moves. Firestore's own disk cache is the offline copy, so there
/// is no second local store to keep in step.
class FirestoreCollectionStore implements CollectionStore {
  FirestoreCollectionStore(this.userId);

  /// Whose collection this is. Anonymous accounts have one too; linking an
  /// anonymous account keeps its id, so what was found before signing in comes
  /// along by itself.
  final String userId;

  CollectionReference<Map<String, Object?>> get _collection => FirebaseFirestore
      .instance
      .collection('users')
      .doc(userId)
      .collection('collection');

  @override
  Future<Map<String, CollectionEntry>> load() async {
    try {
      // Falls back to the disk cache when the server cannot be reached, which
      // is what makes the collection readable on a plane.
      final snapshot = await _collection.get();
      final entries = <String, CollectionEntry>{};

      for (final document in snapshot.docs) {
        try {
          entries[document.id] = CollectionEntry.fromJson(document.data());
        } catch (error, stack) {
          // One unreadable record must not cost the user the rest.
          _report(error, stack, 'reading collection entry ${document.id}');
        }
      }

      return entries;
    } catch (error, stack) {
      _report(error, stack, 'reading the collection');
      return const {};
    }
  }

  @override
  void write(CollectionEntry entry) {
    unawaited(
      _collection
          .doc(entry.creatureId)
          .set(entry.toJson())
          .catchError(
            (Object error, StackTrace stack) =>
                _report(error, stack, 'saving a find'),
          ),
    );
  }
}

/// A collection with nowhere to go.
///
/// Used when there is no account to hang one on: the first launch with no
/// network, before anonymous sign-in has ever succeeded. Finds still show up
/// for the rest of the session; they are not kept.
class UnsavedCollectionStore implements CollectionStore {
  const UnsavedCollectionStore();

  @override
  Future<Map<String, CollectionEntry>> load() async => const {};

  @override
  void write(CollectionEntry entry) {}
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
