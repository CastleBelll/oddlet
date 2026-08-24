import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daily_egg.dart';
import 'daily_egg_store.dart';

final dailyEggStoreProvider = Provider<DailyEggStore>((ref) => DailyEggStore());

/// Injectable so tests can decide what "now" means.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final dailyEggControllerProvider =
    AsyncNotifierProvider<DailyEggController, DailyEgg>(DailyEggController.new);

/// Holds today's egg and records what the user does to it.
class DailyEggController extends AsyncNotifier<DailyEgg> {
  /// Taps arrive far faster than a disk write is worth, so writes are batched.
  static const _flushInterval = Duration(seconds: 1);

  Timer? _flushTimer;

  @override
  Future<DailyEgg> build() async {
    ref.onDispose(() => _flushTimer?.cancel());

    final store = ref.read(dailyEggStoreProvider);
    final stored = await store.load();
    final now = ref.read(clockProvider)();

    // An egg from an earlier day has had its chance; today gets a new one.
    if (stored == null || stored.day != DailyEgg.dayOf(now)) {
      final fresh = DailyEgg.startOf(now);
      await store.save(fresh);
      return fresh;
    }

    return stored;
  }

  void recordTouch() => _record((egg) => egg.touched());

  void recordShake() => _record((egg) => egg.shaken());

  /// Spends today's egg. Nothing else happens to it until tomorrow.
  Future<void> recordHatch(String creatureId) async {
    final egg = state.value;
    if (egg == null || egg.isHatched) {
      return;
    }

    state = AsyncData(egg.hatchedInto(creatureId, ref.read(clockProvider)()));
    await flush();
  }

  /// Hands back a whole egg for today, discarding whatever happened to the
  /// current one.
  ///
  /// One egg a day makes the loop, and also makes it slow to try things out.
  /// Only ever called from a debug-only affordance, so this never reaches a
  /// released build. It asserts rather than trusting that.
  Future<void> resetToday() async {
    assert(
      kDebugMode,
      'resetToday hands out a second egg for the day; it must not run in a '
      'release build',
    );

    final fresh = DailyEgg.startOf(ref.read(clockProvider)());
    state = AsyncData(fresh);
    await flush();
  }

  void _record(DailyEgg Function(DailyEgg) change) {
    final egg = state.value;
    if (egg == null) {
      return; // Still loading; there is no egg to record against yet.
    }
    if (egg.isHatched) {
      return; // Handling an empty shell changes nothing.
    }

    // Past midnight the user is holding a different egg, and what they do now
    // belongs to that one.
    final now = ref.read(clockProvider)();
    if (egg.day != DailyEgg.dayOf(now)) {
      state = AsyncData(change(DailyEgg.startOf(now)));
      unawaited(flush());
      return;
    }

    state = AsyncData(change(egg));
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(_flushInterval, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  /// Writes the egg out now. Call this when the app is about to go away, so a
  /// batch in flight is not lost.
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;

    final egg = state.value;
    if (egg == null) {
      return;
    }
    await ref.read(dailyEggStoreProvider).save(egg);
  }
}
