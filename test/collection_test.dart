import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oddlet/features/collection/collection_controller.dart';
import 'package:oddlet/features/collection/collection_entry.dart';
import 'package:oddlet/features/egg/daily_egg.dart';
import 'package:oddlet/features/egg/daily_egg_controller.dart';

void main() {
  final noon = DateTime(2026, 8, 24, 12);

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

  group('CollectionEntry', () {
    test('remembers the find that filled the slot', () {
      final entry = CollectionEntry.firstFind('ghost_chick', noon);
      final again = entry.foundAgain(DateTime(2026, 9, 1, 9));

      expect(again.firstFoundAt, noon, reason: 'the first find never moves');
      expect(again.lastFoundAt, DateTime(2026, 9, 1, 9));
      expect(again.count, 2);
    });

    test('survives a round trip through storage', () {
      final entry = CollectionEntry.firstFind(
        'ghost_chick',
        noon,
      ).foundAgain(noon);

      expect(CollectionEntry.fromJson(entry.toJson()), entry);
    });

    test('refuses a record it cannot read', () {
      expect(
        () => CollectionEntry.fromJson({'creatureId': 'ghost_chick'}),
        throwsFormatException,
      );
      expect(
        () => CollectionEntry.fromJson({
          'creatureId': 'ghost_chick',
          'firstFoundAt': noon.toIso8601String(),
          'lastFoundAt': noon.toIso8601String(),
          'count': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('CollectionController', () {
    test('starts empty', () async {
      final container = containerAt(noon);

      final found = await container.read(collectionControllerProvider.future);

      expect(found, isEmpty);
    });

    test('reports the first find as new and later ones as not', () async {
      final container = containerAt(noon);
      await container.read(collectionControllerProvider.future);
      final controller = container.read(collectionControllerProvider.notifier);

      expect(await controller.record('ghost_chick'), isTrue);
      expect(await controller.record('ghost_chick'), isFalse);
    });

    test('counts duplicates instead of discarding them', () async {
      final container = containerAt(noon);
      await container.read(collectionControllerProvider.future);
      final controller = container.read(collectionControllerProvider.notifier);

      await controller.record('ghost_chick');
      await controller.record('ghost_chick');

      final entry = container
          .read(collectionControllerProvider)
          .requireValue['ghost_chick']!;
      expect(entry.count, 2);
    });

    test('keeps a find made before the collection finished loading', () async {
      final container = containerAt(noon);

      // No await on the provider first: a hatch can land while the stored
      // collection is still being read, and a load that finishes afterwards
      // must not wipe the find.
      await container
          .read(collectionControllerProvider.notifier)
          .record('ghost_chick');

      final found = await container.read(collectionControllerProvider.future);
      expect(found.keys, ['ghost_chick']);
    });

    test('keeps the collection across a restart', () async {
      final first = containerAt(noon);
      await first.read(collectionControllerProvider.future);
      await first
          .read(collectionControllerProvider.notifier)
          .record('ghost_chick');

      final second = containerAt(DateTime(2026, 9, 1));
      final found = await second.read(collectionControllerProvider.future);

      expect(found.keys, ['ghost_chick']);
    });

    test('drops only the damaged entry, not the whole collection', () async {
      SharedPreferences.setMockInitialValues({
        'oddlet.collection': jsonEncode({
          'ghost_chick': CollectionEntry.firstFind('ghost_chick', noon).toJson(),
          'broken': {'creatureId': 'broken'},
        }),
      });
      final container = containerAt(noon);

      final found = await container.read(collectionControllerProvider.future);

      expect(found.keys, ['ghost_chick']);
    });
  });

  group('a spent egg', () {
    test('remembers what it became', () {
      final egg = DailyEgg.startOf(noon).hatchedInto('ghost_chick', noon);

      expect(egg.isHatched, isTrue);
      expect(egg.resultCreatureId, 'ghost_chick');
      expect(DailyEgg.fromJson(egg.toJson()), egg);
    });

    test('stops counting handling', () async {
      final container = containerAt(noon);
      await container.read(dailyEggControllerProvider.future);
      final controller = container.read(dailyEggControllerProvider.notifier);

      controller.recordTouch();
      await controller.recordHatch('ghost_chick');
      controller.recordTouch();
      controller.recordShake();

      final egg = container.read(dailyEggControllerProvider).requireValue;
      expect(egg.touchCount, 1, reason: 'only the tap before hatching counts');
      expect(egg.shakeCount, 0);
    });

    test('stays spent across a restart', () async {
      final first = containerAt(noon);
      await first.read(dailyEggControllerProvider.future);
      await first
          .read(dailyEggControllerProvider.notifier)
          .recordHatch('ghost_chick');

      final second = containerAt(DateTime(2026, 8, 24, 22));
      final egg = await second.read(dailyEggControllerProvider.future);

      expect(egg.isHatched, isTrue);
    });

    test('is replaced by a whole egg the next day', () async {
      final today = containerAt(noon);
      await today.read(dailyEggControllerProvider.future);
      await today
          .read(dailyEggControllerProvider.notifier)
          .recordHatch('ghost_chick');

      final tomorrow = containerAt(DateTime(2026, 8, 25, 9));
      final egg = await tomorrow.read(dailyEggControllerProvider.future);

      expect(egg.isHatched, isFalse);
    });
  });
}
