import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';

import 'features/account/account_controller.dart';
import 'features/account/onboarding.dart';
import 'features/egg/home_screen.dart';
import 'features/naming/naming_repository.dart';
import 'features/intro/intro_controller.dart';
import 'features/intro/intro_screen.dart';
import 'firebase_options.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: OddletApp()));
}

/// Whether this account has already chosen a nickname.
///
/// Its own provider rather than a field on the account, so that finishing the
/// nickname step can invalidate it and the app moves on by itself.
final handleProvider = FutureProvider<String?>((ref) async {
  final uid = ref.watch(accountProvider).value?.uid;
  if (uid == null) {
    return null;
  }
  return ref.watch(namingRepositoryProvider).myHandle(uid);
});

/// Everything that has to be true before the egg.
///
/// In order: an account, a nickname, and the opening. The account comes first
/// because everything the app keeps belongs to one — the collection, a name
/// other people live with — and none of that can be handed to somebody who
/// never chose an account. The nickname comes next because the first thing the
/// app can offer is naming something, and a name has to be signed.
class _Entry extends ConsumerWidget {
  const _Entry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const waiting = ColoredBox(color: OddletColors.ink);

    final account = ref.watch(accountProvider);
    if (account.isLoading) {
      return waiting;
    }
    if (account.value == null) {
      return const SignInScreen();
    }

    final handle = ref.watch(handleProvider);
    if (handle.isLoading) {
      return waiting;
    }
    if ((handle.value ?? '').isEmpty) {
      return HandleScreen(
        onDone: () => ref.invalidate(handleProvider),
      );
    }

    // Nothing on screen until the answer is known: a flash of the egg followed
    // by an opening would be worse than a moment of dark.
    return switch (ref.watch(introSeenProvider)) {
      AsyncData(value: true) => const HomeScreen(),
      AsyncData() => const IntroScreen(),
      _ => waiting,
    };
  }
}

/// Picks the language to run in.
///
/// Flutter's own resolution falls back to the first supported locale, and the
/// generated list is alphabetical: without this, someone whose phone is set to
/// a language Oddlet-! does not speak would be shown German. English is the
/// language the app is written in, so it is what an unknown reader gets.
Locale resolveLocale(List<Locale>? deviceLocales, Iterable<Locale> supported) {
  final wanted = deviceLocales ?? const <Locale>[];
  final understood = wanted.any(
    (locale) =>
        supported.any((option) => option.languageCode == locale.languageCode),
  );

  // Only the no-match case is ours. Everything else goes through Flutter's
  // resolution, which is what gets zh-Hant to the traditional translation
  // rather than to the simplified one.
  return understood
      ? basicLocaleListResolution(wanted, supported)
      : const Locale('en');
}

class OddletApp extends StatelessWidget {
  const OddletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveLocale,
      // Dark only: the hatch sequence is staged against a dark room.
      theme: oddletDarkTheme(),
      home: const _Entry(),
    );
  }
}
