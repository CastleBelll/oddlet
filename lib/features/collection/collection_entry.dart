import 'package:flutter/foundation.dart';

/// One creature the user has found, and how their history with it went.
@immutable
class CollectionEntry {
  const CollectionEntry({
    required this.species,
    required this.firstFoundAt,
    required this.lastFoundAt,
    required this.count,
  });

  /// Which of the season's species this is.
  ///
  /// The species is the identity, not the rule that produced it: it is what
  /// has a look, what a name is registered against, and what fills a slot.
  final int species;

  /// The find that mattered: the one that filled the empty slot.
  final DateTime firstFoundAt;
  final DateTime lastFoundAt;

  /// Including the first. Duplicates are worth showing, not hiding.
  final int count;

  factory CollectionEntry.firstFind(int species, DateTime at) =>
      CollectionEntry(
        species: species,
        firstFoundAt: at,
        lastFoundAt: at,
        count: 1,
      );

  CollectionEntry foundAgain(DateTime at) => CollectionEntry(
    species: species,
    firstFoundAt: firstFoundAt,
    lastFoundAt: at,
    count: count + 1,
  );

  Map<String, Object?> toJson() => {
    'species': species,
    'firstFoundAt': firstFoundAt.toIso8601String(),
    'lastFoundAt': lastFoundAt.toIso8601String(),
    'count': count,
  };

  /// Throws [FormatException] on anything it cannot read, so the caller can
  /// decide what a damaged record means.
  factory CollectionEntry.fromJson(Map<String, Object?> json) {
    final species = json['species'];
    final firstFoundAt = json['firstFoundAt'];
    final lastFoundAt = json['lastFoundAt'];
    final count = json['count'];

    if (species is! int ||
        species < 0 ||
        firstFoundAt is! String ||
        lastFoundAt is! String ||
        count is! int ||
        count < 1) {
      throw const FormatException('collection entry is not readable');
    }

    return CollectionEntry(
      species: species,
      firstFoundAt: DateTime.parse(firstFoundAt),
      lastFoundAt: DateTime.parse(lastFoundAt),
      count: count,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CollectionEntry &&
      other.species == species &&
      other.firstFoundAt == firstFoundAt &&
      other.lastFoundAt == lastFoundAt &&
      other.count == count;

  @override
  int get hashCode => Object.hash(species, firstFoundAt, lastFoundAt, count);
}
