import 'package:flutter/foundation.dart';

/// A creature that somebody has already named.
///
/// Read-only on this side. Names are written by the naming function and never
/// from here, and once written they do not change, so this is a record rather
/// than a value being edited.
@immutable
class SpeciesName {
  const SpeciesName({
    required this.species,
    required this.name,
    required this.discovererHandle,
    required this.discovererUid,
    this.namedAt,
  });

  final int species;

  /// What the first discoverer called it, spelled the way they spelled it.
  final String name;

  /// The nickname they signed it with. Never their account name: this is read
  /// by strangers.
  final String discovererHandle;

  /// Used only to tell a reader that the name is theirs. Never shown.
  final String discovererUid;

  final DateTime? namedAt;

  /// Throws [FormatException] on a record it cannot read, so a half-written
  /// document never turns into a creature called "null".
  factory SpeciesName.fromFirestore(int species, Map<String, Object?> data) {
    final name = data['name'];
    final handle = data['discovererHandle'];
    final uid = data['discovererUid'];

    if (name is! String || name.isEmpty || handle is! String || uid is! String) {
      throw const FormatException('species name is not readable');
    }

    return SpeciesName(
      species: species,
      name: name,
      discovererHandle: handle,
      discovererUid: uid,
      // Firestore hands back its own Timestamp. Reading it as a DateTime only
      // when it already is one keeps this file free of the SDK, so it can be
      // built in a plain test.
      namedAt: data['namedAt'] is DateTime ? data['namedAt'] as DateTime : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SpeciesName &&
      other.species == species &&
      other.name == name &&
      other.discovererHandle == discovererHandle &&
      other.discovererUid == discovererUid &&
      other.namedAt == namedAt;

  @override
  int get hashCode =>
      Object.hash(species, name, discovererHandle, discovererUid, namedAt);
}
