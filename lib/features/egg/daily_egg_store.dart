import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_egg.dart';

/// Keeps today's egg on the device between launches.
///
/// Only the egg in progress lives here. Hatched results belong to the account
/// rather than the handset, and go to the backend instead.
class DailyEggStore {
  static const _key = 'oddlet.daily_egg';

  /// Returns null when nothing is stored, or when what is stored cannot be
  /// read. A caller that gets null should start a fresh egg.
  Future<DailyEgg?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_key);
    if (stored == null) {
      return null;
    }

    try {
      return DailyEgg.fromJson(jsonDecode(stored) as Map<String, Object?>);
    } on FormatException catch (error, stack) {
      // A corrupt record must not brick the app, but it is worth reporting:
      // it means something wrote a shape we did not expect.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'oddlet',
          context: ErrorDescription('reading the stored daily egg'),
        ),
      );
      await preferences.remove(_key);
      return null;
    }
  }

  Future<void> save(DailyEgg egg) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, jsonEncode(egg.toJson()));
  }
}
