import 'package:flutter/foundation.dart';

/// The egg the user holds for one day, and what they have done to it.
///
/// This is working state, not a record worth keeping: it lives on the device
/// until the egg hatches, at which point only the outcome is worth uploading.
/// Counting taps into the cloud one by one would cost far more than it is
/// worth.
@immutable
class DailyEgg {
  const DailyEgg({
    required this.day,
    required this.createdAt,
    this.touchCount = 0,
    this.shakeCount = 0,
    this.hatchedAt,
    this.resultCreatureId,
  });

  /// Ceiling on any single count.
  ///
  /// Nothing legitimate reaches this in a day, so a value at the cap means the
  /// clock was moved or the stored data was edited. Capping keeps a nonsense
  /// number from reaching the rule engine.
  static const maxCount = 100000;

  /// The calendar day this egg belongs to, at local midnight.
  final DateTime day;
  final DateTime createdAt;
  final int touchCount;
  final int shakeCount;

  /// Set once the egg has been opened. A spent egg is not replaced until the
  /// next day: one egg a day is the whole shape of the loop.
  final DateTime? hatchedAt;
  final String? resultCreatureId;

  bool get isHatched => hatchedAt != null;

  factory DailyEgg.startOf(DateTime now) =>
      DailyEgg(day: dayOf(now), createdAt: now);

  /// Local midnight of [moment]; one calendar day is one egg.
  static DateTime dayOf(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  DailyEgg touched() => _copyWith(touchCount: _bump(touchCount));

  DailyEgg shaken() => _copyWith(shakeCount: _bump(shakeCount));

  DailyEgg hatchedInto(String creatureId, DateTime at) => DailyEgg(
    day: day,
    createdAt: createdAt,
    touchCount: touchCount,
    shakeCount: shakeCount,
    hatchedAt: at,
    resultCreatureId: creatureId,
  );

  static int _bump(int count) => count >= maxCount ? maxCount : count + 1;

  DailyEgg _copyWith({int? touchCount, int? shakeCount}) => DailyEgg(
    day: day,
    createdAt: createdAt,
    touchCount: touchCount ?? this.touchCount,
    shakeCount: shakeCount ?? this.shakeCount,
    hatchedAt: hatchedAt,
    resultCreatureId: resultCreatureId,
  );

  Map<String, Object?> toJson() => {
    'day': _formatDay(day),
    'createdAt': createdAt.toIso8601String(),
    'touchCount': touchCount,
    'shakeCount': shakeCount,
    'hatchedAt': hatchedAt?.toIso8601String(),
    'resultCreatureId': resultCreatureId,
  };

  /// Throws [FormatException] on anything it cannot read, so the caller can
  /// decide that a broken record means "start a fresh egg".
  factory DailyEgg.fromJson(Map<String, Object?> json) {
    final day = json['day'];
    final createdAt = json['createdAt'];
    if (day is! String || createdAt is! String) {
      throw const FormatException('daily egg is missing its dates');
    }

    final hatchedAt = json['hatchedAt'];
    final resultCreatureId = json['resultCreatureId'];
    if (hatchedAt is! String? || resultCreatureId is! String?) {
      throw const FormatException('daily egg has an unreadable hatch record');
    }

    return DailyEgg(
      day: DateTime.parse(day),
      createdAt: DateTime.parse(createdAt),
      touchCount: _readCount(json['touchCount']),
      shakeCount: _readCount(json['shakeCount']),
      hatchedAt: hatchedAt == null ? null : DateTime.parse(hatchedAt),
      resultCreatureId: resultCreatureId,
    );
  }

  static int _readCount(Object? value) {
    if (value is! int || value < 0) {
      throw const FormatException('daily egg has a count that is not a count');
    }
    return value > maxCount ? maxCount : value;
  }

  static String _formatDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is DailyEgg &&
      other.day == day &&
      other.createdAt == createdAt &&
      other.touchCount == touchCount &&
      other.shakeCount == shakeCount &&
      other.hatchedAt == hatchedAt &&
      other.resultCreatureId == resultCreatureId;

  @override
  int get hashCode => Object.hash(
    day,
    createdAt,
    touchCount,
    shakeCount,
    hatchedAt,
    resultCreatureId,
  );

  @override
  String toString() =>
      'DailyEgg(${_formatDay(day)}, touches: $touchCount, shakes: $shakeCount)';
}
