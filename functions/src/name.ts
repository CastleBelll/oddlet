/**
 * Deciding whether a name may exist, and what makes two names the same one.
 *
 * Pure on purpose: nothing here touches Firestore, so all of it can be tested
 * without a project, and the word list arrives as an argument rather than
 * living in this repository — which is public, and would otherwise publish
 * exactly what the filter is looking for.
 */

export type NameProblem =
  | "blank"
  | "tooShort"
  | "tooLong"
  | "badCharacters"
  | "repeats"
  | "blocked";

export const NAME_MIN = 2;
export const NAME_MAX = 20;

/** How many times one character may repeat before it stops being a name. */
const MAX_RUN = 3;

/**
 * A term shorter than this only matches a whole word. Substring matching on a
 * three-letter term turns half the dictionary into a rejection, and a name
 * refused for no visible reason is worse than one more entry in the list.
 */
const SUBSTRING_FROM = 4;

const ALLOWED = /^[\p{L}\p{M}\p{N} \-']+$/u;
const HAS_LETTER = /\p{L}/u;
const ZALGO = /\p{M}{3,}/u;
const INVISIBLE = /[­​-‏⁠-⁤﻿︀-️]/gu;

const graphemes = new Intl.Segmenter(undefined, { granularity: "grapheme" });

/** The name as it would be shown: outer space gone, inner runs collapsed. */
export function tidy(input: string): string {
  return input.trim().replace(/\s+/gu, " ");
}

function count(name: string): number {
  let total = 0;
  for (const _ of graphemes.segment(name)) {
    total += 1;
  }
  return total;
}

/**
 * What is wrong with the shape of `input`, ignoring the word list.
 *
 * The client runs the same checks so it can object while someone types, but
 * this is the copy that decides.
 */
export function checkShape(input: string): NameProblem | null {
  const name = tidy(input);
  if (name.length === 0) {
    return "blank";
  }

  const length = count(name);
  if (length < NAME_MIN) {
    return "tooShort";
  }
  if (length > NAME_MAX) {
    return "tooLong";
  }

  // Letters, the marks that go on them, digits, and the two joiners real
  // names use. With no dot, colon, slash or at sign there is no address to
  // type, so links need no rule of their own.
  if (!ALLOWED.test(name)) {
    return "badCharacters";
  }
  // Digits belong inside a name and not as the whole of one: nobody gets to
  // own 404.
  if (!HAS_LETTER.test(name)) {
    return "badCharacters";
  }

  if (hasLongRun(name) || ZALGO.test(name)) {
    return "repeats";
  }

  return null;
}

/**
 * What makes two names the same name.
 *
 * This is the id of the `speciesNames` document, so it is the whole of the
 * uniqueness rule. Case, spacing and punctuation are not differences:
 * `Dawn Runner`, `dawn-runner` and `DAWNRUNNER` are one name, and only the
 * first person to register it has it.
 */
export function duplicateKey(input: string): string {
  return fold(input).replace(/[^\p{L}\p{N}]/gu, "");
}

/**
 * What the word list is matched against.
 *
 * Everything `duplicateKey` does, plus the substitutions people reach for
 * when they want a word to get past a filter: a Cyrillic а for a Latin a, a
 * zero for an o, a held-down letter.
 *
 * Repeats collapse all the way to one, on both the name and the term, so
 * `baaaad` and `bad` are the same word. That shortens terms as well, which is
 * why `SUBSTRING_FROM` is measured after this runs: `hell` collapses to three
 * characters and stops matching inside `Michelle`.
 */
export function filterKey(input: string): string {
  const folded = duplicateKey(input).replace(
    /[аеорсухαο0134578]/gu,
    (character) => CONFUSABLE[character] ?? character,
  );

  return folded.replace(/(.)\1+/gu, "$1");
}

/** Whether any of `terms` appears in `input`. Terms are given as plain text. */
export function isBlocked(input: string, terms: readonly string[]): boolean {
  const key = filterKey(input);
  const words = new Set(tidy(input).split(" ").map(filterKey));

  return terms.some((raw) => {
    const term = filterKey(raw);
    if (term.length === 0) {
      return false;
    }
    return term.length >= SUBSTRING_FROM
      ? key.includes(term)
      : words.has(term);
  });
}

/**
 * Everything that has to happen before two spellings can be compared:
 * compatibility forms folded together, case removed, invisible characters
 * dropped.
 */
function fold(input: string): string {
  return tidy(input).normalize("NFKC").toLowerCase().replace(INVISIBLE, "");
}

const CONFUSABLE: Record<string, string> = {
  "а": "a",
  "е": "e",
  "о": "o",
  "р": "p",
  "с": "c",
  "у": "y",
  "х": "x",
  "α": "a",
  "ο": "o",
  "0": "o",
  "1": "i",
  "3": "e",
  "4": "a",
  "5": "s",
  "7": "t",
  "8": "b",
};

function hasLongRun(name: string): boolean {
  let previous = "";
  let run = 0;

  for (const { segment } of graphemes.segment(name)) {
    run = segment === previous ? run + 1 : 1;
    if (run > MAX_RUN) {
      return true;
    }
    previous = segment;
  }

  return false;
}
