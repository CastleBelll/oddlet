import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';

import 'features/account/account_controller.dart';
import 'features/egg/home_screen.dart';
import 'features/intro/intro_controller.dart';
import 'features/intro/intro_screen.dart';
import 'firebase_options.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: OddletApp()));
}

/// The opening plays once, then never again.
class _Entry extends ConsumerWidget {
  const _Entry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Starts signing in without holding anything up. Today's egg is on the
    // device, so the loop works whether or not this lands.
    ref.watch(accountProvider);

    final seen = ref.watch(introSeenProvider);

    // Nothing on screen until the answer is known: a flash of the egg followed
    // by an opening would be worse than a moment of dark.
    return switch (seen) {
      AsyncData(value: true) => const HomeScreen(),
      AsyncData() => const IntroScreen(),
      _ => const ColoredBox(color: OddletColors.ink),
    };
  }
}

class OddletApp extends StatelessWidget {
  const OddletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Dark only: the hatch sequence is staged against a dark room.
      theme: oddletDarkTheme(),
      home: const _Entry(),
    );
  }
}
