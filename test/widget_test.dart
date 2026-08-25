import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddlet/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oddlet/features/egg/daily_egg.dart';
import 'package:oddlet/features/egg/daily_egg_controller.dart';
import 'package:oddlet/features/egg/egg_appearance.dart';
import 'package:oddlet/features/egg/egg_view.dart';
import 'package:oddlet/features/egg/home_screen.dart';
import 'package:oddlet/features/egg/shake_detector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oddlet/features/account/account_controller.dart';
import 'package:oddlet/features/egg/hatch_reveal.dart';
import 'package:oddlet/features/naming/naming_repository.dart';
import 'package:oddlet/features/naming/species_name.dart';
import 'package:oddlet/features/rules/creature.dart';
import 'package:oddlet/main.dart';
import 'package:oddlet/theme.dart';

/// Settled, without a Firebase to settle against.
class _StubAccount extends AccountController {
  @override
  Future<User?> build() async => null;
}

/// A world where nothing has been named yet, and no network to ask.
class _NoNames implements NamingRepository {
  @override
  Future<SpeciesName?> lookup(int species) async => null;

  @override
  Future<String?> myHandle(String uid) async => null;

  @override
  Future<NameRejection?> register({
    required int species,
    required String name,
    String? handle,
  }) async => NameRejection.unreachable;
}

/// A sample the detector should read as a shake of [magnitude] m/s^2 along x.
UserAccelerometerEvent sample(double magnitude, DateTime at) =>
    UserAccelerometerEvent(magnitude, 0, 0, at);

void main() {
  // Today's egg is read from disk before the shell can be drawn.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget appUnder(Locale locale) => ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The same resolution the real app uses, so the fallback test measures
      // production behaviour rather than the test's own wiring.
      localeListResolutionCallback: resolveLocale,
      home: HomeScreen(
        shakeDetector: ShakeDetector(samples: const Stream.empty()),
      ),
    ),
  );

  /// Pumps the app and lets the daily egg finish loading.
  Future<void> pumpApp(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(appUnder(locale));
    await tester.pump(); // resolve the stored egg
    await tester.pump(); // rebuild with it
  }

  group('home screen', () {
    testWidgets('shows the wordmark and the egg', (tester) async {
      await pumpApp(tester, const Locale('en'));

      expect(find.text('Oddlet-!'), findsOneWidget);
      expect(find.byType(EggView), findsOneWidget);
    });

    testWidgets('keeps the wordmark untranslated', (tester) async {
      await pumpApp(tester, const Locale('ko'));

      // The wordmark is the brand mark, not copy.
      expect(find.text('Oddlet-!'), findsOneWidget);
    });

    testWidgets('egg keeps animating without settling', (tester) async {
      await pumpApp(tester, const Locale('en'));

      // A repeating idle animation never settles; pumpAndSettle would time out.
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.hasRunningAnimations, isTrue);
    });
  });

  group('localization', () {
    testWidgets('announces the egg in the device language', (tester) async {
      await pumpApp(tester, const Locale('ko'));

      expect(
        tester.getSemantics(find.byType(EggView)).label,
        '알',
      );
    });

    testWidgets('falls back to English for an unsupported language', (
      tester,
    ) async {
      const unsupported = Locale('fi');
      // Guarded so that shipping Finnish one day fails this test rather than
      // letting it pass for the wrong reason.
      expect(
        AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
        isNot(contains(unsupported.languageCode)),
      );

      await pumpApp(tester, unsupported);

      expect(
        tester.getSemantics(find.byType(EggView)).label,
        'Egg',
      );
    });

    test('every supported locale is declared', () {
      expect(
        AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
        containsAll(<String>[
          'en',
          'ko',
          'ja',
          'zh',
          'es',
          'pt',
          'fr',
          'de',
          'id',
        ]),
      );
    });

    test('traditional Chinese is its own translation, not just zh', () {
      // Simplified and traditional are different scripts, and a reader of one
      // does not simply read the other. gen-l10n only emits the script variant
      // if the file is named for it, so this catches a rename.
      expect(
        AppLocalizations.supportedLocales,
        contains(
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ),
      );
    });

    test('the wordmark survives every translation', () {
      // The rarity tiers and the wordmark are brand marks, not copy: §1.1 of
      // the plan says the app is called ODDLET in every language.
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);

        expect(l10n.appTitle, 'Oddlet-!', reason: '$locale renamed the app');
        expect(l10n.rarityRare, 'RARE', reason: '$locale translated a tier');
        expect(l10n.revealNew, 'NEW', reason: '$locale translated the badge');
      }
    });
  });

  group('pokeAmplitude', () {
    test('is fully squashed at the moment of contact', () {
      expect(pokeAmplitude(0), 1.0);
    });

    test('never overshoots the contact amplitude', () {
      for (var step = 0; step <= 120; step++) {
        final amplitude = pokeAmplitude(step / 100);

        expect(amplitude.abs(), lessThanOrEqualTo(1.0));
      }
    });

    test('rings back and forth before settling', () {
      // A pure decay would never go negative; the shell must rebound.
      final samples = [
        for (var step = 0; step <= 60; step++) pokeAmplitude(step / 100),
      ];

      expect(samples.any((amplitude) => amplitude < -0.05), isTrue);
    });

    test('has rung out well before the poke window closes', () {
      expect(pokeAmplitude(1.2).abs(), lessThan(0.01));
    });

    test('ignores time before contact', () {
      expect(pokeAmplitude(-1), 0.0);
    });
  });

  group('EggAppearance', () {
    test('gives the same egg the same face all day', () {
      final morning = EggAppearance.forDay(DateTime(2026, 8, 24, 7, 15));
      final evening = EggAppearance.forDay(DateTime(2026, 8, 24, 23, 59));

      expect(morning.shell, evening.shell);
      expect(morning.speckle, evening.speckle);
      expect(morning.textureScale, evening.textureScale);
      expect(morning.blotchiness, evening.blotchiness);
    });

    test('gives a different face the next day', () {
      final today = EggAppearance.forDay(DateTime(2026, 8, 24));
      final tomorrow = EggAppearance.forDay(DateTime(2026, 8, 25));

      expect(today.shell, isNot(tomorrow.shell));
    });

    test('spreads shell colours across the whole hue circle', () {
      final hues = [
        for (var day = 0; day < 200; day++)
          HSVColor.fromColor(
            EggAppearance.forDay(DateTime(2026, 1, 1).add(Duration(days: day))).shell,
          ).hue,
      ];

      // Every 60 degree wedge should be represented over half a year.
      for (var wedge = 0; wedge < 6; wedge++) {
        expect(
          hues.any((hue) => hue >= wedge * 60 && hue < (wedge + 1) * 60),
          isTrue,
          reason: 'no egg in the ${wedge * 60}-${(wedge + 1) * 60} degree wedge',
        );
      }
    });

    test('keeps shells pastel rather than lurid', () {
      for (var day = 0; day < 200; day++) {
        final shell = HSVColor.fromColor(
          EggAppearance.forDay(DateTime(2026, 1, 1).add(Duration(days: day))).shell,
        );

        expect(shell.saturation, lessThanOrEqualTo(0.35));
        expect(shell.value, greaterThanOrEqualTo(0.70));
      }
    });

    test('speckles stay darker than the shell they sit on', () {
      for (var day = 0; day < 50; day++) {
        final appearance = EggAppearance.forDay(
          DateTime(2026, 1, 1).add(Duration(days: day)),
        );

        expect(
          HSVColor.fromColor(appearance.speckle).value,
          lessThan(HSVColor.fromColor(appearance.shell).value),
        );
      }
    });
  });

  group('DailyEgg', () {
    final noon = DateTime(2026, 8, 24, 12);

    test('belongs to the calendar day it was started on', () {
      final egg = DailyEgg.startOf(noon);

      expect(egg.day, DateTime(2026, 8, 24));
      expect(egg.createdAt, noon);
      expect(egg.touchCount, 0);
      expect(egg.shakeCount, 0);
    });

    test('counts touches and shakes separately', () {
      final egg = DailyEgg.startOf(noon).touched().touched().shaken();

      expect(egg.touchCount, 2);
      expect(egg.shakeCount, 1);
    });

    test('survives a round trip through storage', () {
      final egg = DailyEgg.startOf(noon).touched().shaken();

      expect(DailyEgg.fromJson(egg.toJson()), egg);
    });

    test('refuses a record it cannot read', () {
      expect(
        () => DailyEgg.fromJson({'day': '2026-08-24'}),
        throwsFormatException,
      );
      expect(
        () => DailyEgg.fromJson({
          'day': '2026-08-24',
          'createdAt': noon.toIso8601String(),
          'touchCount': -5,
          'shakeCount': 0,
        }),
        throwsFormatException,
      );
    });

    test('caps counts that no real day could produce', () {
      final tampered = DailyEgg.fromJson({
        'day': '2026-08-24',
        'createdAt': noon.toIso8601String(),
        'touchCount': 999999999,
        'shakeCount': 0,
      });

      expect(tampered.touchCount, DailyEgg.maxCount);
      // And it does not climb any further.
      expect(tampered.touched().touchCount, DailyEgg.maxCount);
    });
  });

  group('DailyEggController', () {
    late DateTime now;

    ProviderContainer containerAt(DateTime moment) {
      now = moment;
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(() => now)],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('hands out a fresh egg on a first run', () async {
      final container = containerAt(DateTime(2026, 8, 24, 9));

      final egg = await container.read(dailyEggControllerProvider.future);

      expect(egg.day, DateTime(2026, 8, 24));
      expect(egg.touchCount, 0);
    });

    test('keeps counts across a restart on the same day', () async {
      final first = containerAt(DateTime(2026, 8, 24, 9));
      await first.read(dailyEggControllerProvider.future);
      first.read(dailyEggControllerProvider.notifier)
        ..recordTouch()
        ..recordTouch()
        ..recordShake();
      await first.read(dailyEggControllerProvider.notifier).flush();

      final second = containerAt(DateTime(2026, 8, 24, 21));
      final egg = await second.read(dailyEggControllerProvider.future);

      expect(egg.touchCount, 2);
      expect(egg.shakeCount, 1);
    });

    test('starts over the next day', () async {
      final yesterday = containerAt(DateTime(2026, 8, 24, 9));
      await yesterday.read(dailyEggControllerProvider.future);
      yesterday.read(dailyEggControllerProvider.notifier).recordTouch();
      await yesterday.read(dailyEggControllerProvider.notifier).flush();

      final today = containerAt(DateTime(2026, 8, 25, 9));
      final egg = await today.read(dailyEggControllerProvider.future);

      expect(egg.day, DateTime(2026, 8, 25));
      expect(egg.touchCount, 0);
    });

    test('rolls over when midnight passes with the app open', () async {
      final container = containerAt(DateTime(2026, 8, 24, 23, 59));
      await container.read(dailyEggControllerProvider.future);
      container.read(dailyEggControllerProvider.notifier).recordTouch();

      now = DateTime(2026, 8, 25, 0, 1);
      container.read(dailyEggControllerProvider.notifier).recordTouch();

      final egg = container.read(dailyEggControllerProvider).requireValue;
      expect(egg.day, DateTime(2026, 8, 25));
      expect(egg.touchCount, 1, reason: 'the tap belongs to the new egg');
    });

    test('starts fresh rather than crashing on a corrupt record', () async {
      SharedPreferences.setMockInitialValues({
        'oddlet.daily_egg': 'not json at all',
      });
      final container = containerAt(DateTime(2026, 8, 24, 9));

      final egg = await container.read(dailyEggControllerProvider.future);

      expect(egg.touchCount, 0);
    });
  });

  group('ShakeDetector', () {
    final start = DateTime(2026, 1, 1);

    Future<List<Shake>> detect(List<UserAccelerometerEvent> samples) async {
      final source = StreamController<UserAccelerometerEvent>();
      final detector = ShakeDetector(samples: source.stream);
      final collected = detector.shakes.toList();

      detector.start();
      samples.forEach(source.add);
      // Let every sample reach the detector before tearing it down.
      await source.close();
      await detector.dispose();

      return collected;
    }

    test('ignores ordinary handling below the threshold', () async {
      final shakes = await detect([sample(5, start)]);

      expect(shakes, isEmpty);
    });

    test('reports a shake past the threshold', () async {
      final shakes = await detect([sample(20, start)]);

      expect(shakes, hasLength(1));
      expect(shakes.single.strength, greaterThan(1.0));
    });

    test('reports one event for a single physical shake', () async {
      // A real shake spans many samples over a few tens of milliseconds.
      final shakes = await detect([
        sample(20, start),
        sample(25, start.add(const Duration(milliseconds: 40))),
        sample(18, start.add(const Duration(milliseconds: 90))),
      ]);

      expect(shakes, hasLength(1));
    });

    test('reports the next shake once the cooldown has passed', () async {
      final shakes = await detect([
        sample(20, start),
        sample(20, start.add(const Duration(milliseconds: 400))),
      ]);

      expect(shakes, hasLength(2));
    });

    test('caps strength so a violent shake is not unbounded', () async {
      final shakes = await detect([sample(500, start)]);

      expect(shakes.single.strength, lessThanOrEqualTo(30.0 / 12.0));
    });

    test('takes direction from the sign of the sideways movement', () async {
      final shakes = await detect([
        sample(-20, start),
        sample(20, start.add(const Duration(milliseconds: 400))),
      ]);

      expect(shakes.map((shake) => shake.direction), [-1.0, 1.0]);
    });
  });

  group('hatch reveal', () {
    testWidgets('fits a short screen', (tester) async {
      // The light behind the creature was once a laid-out child, which made
      // the column taller than the screen and overflowed on a real phone.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountProvider.overrideWith(_StubAccount.new),
            namingRepositoryProvider.overrideWithValue(_NoNames()),
          ],
          child: MaterialApp(
            locale: const Locale('ko'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: oddletDarkTheme(),
            home: Scaffold(
              body: HatchReveal(
                hatchling: const Hatchling(
                  species: 0,
                  rarity: Rarity.common,
                ),
                isNew: true,
                foundAt: DateTime(2026, 8, 25, 12),
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      // Part way through the arrival, where the light is at its widest.
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });

  group('theme', () {
    test('sets every line in the one poster face', () {
      final theme = oddletDarkTheme();

      // Reads the text theme rather than ThemeData.fontFamily: that is what
      // widgets actually resolve, and a style declared without it would quietly
      // fall back to the system font.
      expect(theme.textTheme.bodyMedium?.fontFamily, oddletFontFamily);
      expect(theme.textTheme.titleLarge?.fontFamily, oddletFontFamily);
    });
  });

  group('SpeciesName', () {
    // What the delete function leaves behind: the name every other finder is
    // already using, with nobody credited for it. Emptied rather than removed
    // because a document missing fields is refused outright, and a name that
    // stops being readable is a name that has effectively been deleted.
    test('reads a record whose discoverer has deleted their account', () {
      final name = SpeciesName.fromFirestore(136, const {
        'name': 'Bam',
        'nameKey': 'bam',
        'discovererUid': '',
        'discovererHandle': '',
      });

      expect(name.name, 'Bam');
      expect(name.hasDiscoverer, isFalse);
    });

    test('reports a discoverer while there is one to credit', () {
      final name = SpeciesName.fromFirestore(136, const {
        'name': 'Bam',
        'discovererUid': 'uid',
        'discovererHandle': 'someone',
      });

      expect(name.hasDiscoverer, isTrue);
    });
  });
}
