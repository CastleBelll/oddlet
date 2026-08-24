import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final introSeenProvider = AsyncNotifierProvider<IntroController, bool>(
  IntroController.new,
);

/// Remembers whether the opening has already been read.
///
/// It plays once. Someone opening the app for the tenth time today wants their
/// egg, not an introduction.
class IntroController extends AsyncNotifier<bool> {
  static const _key = 'oddlet.intro_seen';

  @override
  Future<bool> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key) ?? false;
  }

  Future<void> markSeen() async {
    state = const AsyncData(true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, true);
  }
}
