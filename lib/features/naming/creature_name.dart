import 'package:characters/characters.dart';

/// Why a proposed name cannot be sent.
enum NameProblem {
  blank,
  tooShort,
  tooLong,

  /// Something outside letters, digits and the two joiners a name may use.
  /// This is also what stops links: a name cannot contain `.`, `:`, `/` or
  /// `@`, so there is no address to type.
  badCharacters,

  /// A character, or a stack of accents, repeated past the point of being a
  /// name.
  repeats,
}

/// The shortest and longest a name may be, counted in what a reader would
/// call a character.
///
/// Two, because a single letter is a label rather than a name, and there are
/// only so many of them to go round in a world where names are unique.
const nameMinLength = 2;
const nameMaxLength = 20;

/// How many times one character may repeat before it stops being a name.
const _maxRun = 3;

/// The name as it would be registered: outer space gone, inner runs of space
/// collapsed to one.
///
/// Call this before [checkName] and before sending; what is checked has to be
/// what is stored.
String tidyName(String input) => input.trim().replaceAll(RegExp(r'\s+'), ' ');

/// What is wrong with [input], or null if nothing is.
///
/// This exists so the field can object while someone is still typing. It is
/// not a defence: the repository is public, so anything decided here can be
/// read and bypassed. The server decides whether a name is allowed, and this
/// only agrees with it early.
NameProblem? checkName(String input) {
  final name = tidyName(input);
  if (name.isEmpty) {
    return NameProblem.blank;
  }

  final characters = name.characters;
  if (characters.length < nameMinLength) {
    return NameProblem.tooShort;
  }
  if (characters.length > nameMaxLength) {
    return NameProblem.tooLong;
  }

  if (!_allowed.hasMatch(name)) {
    return NameProblem.badCharacters;
  }
  // Digits belong inside a name and not as the whole of one: 404 is a number,
  // and the first person to type it should not own it.
  if (!_hasLetter.hasMatch(name)) {
    return NameProblem.badCharacters;
  }

  if (_hasLongRun(characters) || _zalgo.hasMatch(name)) {
    return NameProblem.repeats;
  }

  return null;
}

/// Letters, the marks that go on them, digits, and the two joiners that turn
/// up inside real names. Everything else — punctuation, symbols, emoji,
/// zero-width and control characters — is out.
final _allowed = RegExp(r"^[\p{L}\p{M}\p{N} \-']+$", unicode: true);

final _hasLetter = RegExp(r'\p{L}', unicode: true);

/// Accents stacked deeper than any writing system needs, which is how a name
/// is made to spill over the line it is drawn on.
final _zalgo = RegExp(r'\p{M}{3,}', unicode: true);

bool _hasLongRun(Characters characters) {
  var previous = '';
  var run = 0;

  for (final character in characters) {
    run = character == previous ? run + 1 : 1;
    if (run > _maxRun) {
      return true;
    }
    previous = character;
  }

  return false;
}
