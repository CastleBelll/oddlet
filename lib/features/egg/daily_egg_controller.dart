import 'dart:async';

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

  void _record(DailyEgg Function(DailyEgg) change) {
    final egg = state.value;
    if (egg == null) {
      return; // Still loading; there is no egg to record against yet.
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
