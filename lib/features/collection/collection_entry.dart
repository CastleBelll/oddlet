import 'package:flutter/foundation.dart';

/// One creature the user has found, and how their history with it went.
@immutable
class CollectionEntry {
  const CollectionEntry({
    required this.creatureId,
    required this.firstFoundAt,
    required this.lastFoundAt,
    required this.count,
  });

  final String creatureId;

  /// The find that mattered: the one that filled the empty slot.
  final DateTime firstFoundAt;
  final DateTime lastFoundAt;

  /// Including the first. Duplicates are worth showing, not hiding.
  final int count;

  factory CollectionEntry.firstFind(String creatureId, DateTime at) =>
      CollectionEntry(
        creatureId: creatureId,
        firstFoundAt: at,
        lastFoundAt: at,
        count: 1,
      );

  CollectionEntry foundAgain(DateTime at) => CollectionEntry(
    creatureId: creatureId,
    firstFoundAt: firstFoundAt,
    lastFoundAt: at,
    count: count + 1,
  );

  Map<String, Object?> toJson() => {
    'creatureId': creatureId,
    'firstFoundAt': firstFoundAt.toIso8601String(),
    'lastFoundAt': lastFoundAt.toIso8601String(),
    'count': count,
  };

  /// Throws [FormatException] on anything it cannot read, so the caller can
  /// decide what a damaged record means.
  factory CollectionEntry.fromJson(Map<String, Object?> json) {
    final creatureId = json['creatureId'];
    final firstFoundAt = json['firstFoundAt'];
    final lastFoundAt = json['lastFoundAt'];
    final count = json['count'];

    if (creatureId is! String ||
        creatureId.isEmpty ||
        firstFoundAt is! String ||
        lastFoundAt is! String ||
        count is! int ||
        count < 1) {
      throw const FormatException('collection entry is not readable');
    }

    return CollectionEntry(
      creatureId: creatureId,
      firstFoundAt: DateTime.parse(firstFoundAt),
      lastFoundAt: DateTime.parse(lastFoundAt),
      count: count,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CollectionEntry &&
      other.creatureId == creatureId &&
      other.firstFoundAt == firstFoundAt &&
      other.lastFoundAt == lastFoundAt &&
      other.count == count;

  @override
  int get hashCode => Object.hash(creatureId, firstFoundAt, lastFoundAt, count);
}
