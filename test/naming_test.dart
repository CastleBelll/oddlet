import 'package:flutter_test/flutter_test.dart';

import 'package:oddlet/features/naming/creature_name.dart';

void main() {
  group('tidyName', () {
    test('registers what the user can see, not what they typed', () {
      expect(tidyName('  새벽  질주자  '), '새벽 질주자');
    });
  });

  group('checkName', () {
    test('accepts a name in any of the languages the app speaks', () {
      for (final name in [
        '새벽 질주자',
        'Dawn Runner',
        '夜明けの走者',
        '破晓奔跑者',
        'Corredor del Alba',
        "Coureur de l'Aube",
        'Läufer der Dämmerung',
        'Pelari Fajar',
      ]) {
        expect(checkName(name), isNull, reason: '$name should be allowed');
      }
    });

    test('turns down a name too short to be one', () {
      expect(checkName(''), NameProblem.blank);
      expect(checkName('   '), NameProblem.blank);
      expect(checkName('가'), NameProblem.tooShort);
    });

    test('turns down a name longer than the space it is drawn in', () {
      expect(checkName('a' * (nameMaxLength + 1)), NameProblem.tooLong);
    });

    test('counts a character the way a reader does', () {
      // One flag is one character to a person and several code units to Dart.
      // Counting code units would let a name run off the card.
      expect(checkName('🇰🇷🇰🇷'), NameProblem.badCharacters);
      expect(checkName('José García'), isNull);
    });

    test('leaves no way to type an address', () {
      // The character set is what stops links; there is no separate rule to
      // forget to update.
      for (final name in [
        'oddlet.com',
        'http://x.kr',
        '@handle',
        'buy now/cheap',
      ]) {
        expect(checkName(name), NameProblem.badCharacters, reason: name);
      }
    });

    test('turns down symbols, emoji and invisible characters', () {
      expect(checkName('cool 😎 chick'), NameProblem.badCharacters);
      expect(checkName('name​here'), NameProblem.badCharacters);
    });

    test('refuses a name that is only digits', () {
      // Nobody gets to own 404.
      expect(checkName('404'), NameProblem.badCharacters);
      expect(checkName('Chick 404'), isNull, reason: 'digits inside are fine');
    });

    test('refuses a character held down', () {
      expect(checkName('aaaaaaa'), NameProblem.repeats);
      expect(checkName('ㅋㅋㅋㅋㅋㅋ'), NameProblem.repeats);
      expect(checkName('aaa'), isNull, reason: 'a short run is still a name');
    });

    test('refuses accents stacked to break the line', () {
      expect(checkName('hè́̂̃llo'), NameProblem.repeats);
      expect(checkName('café'), isNull, reason: 'one accent is a word');
    });
  });
}
