import { describe, expect, test } from "vitest";

import { checkShape, duplicateKey, isBlocked, NAME_MAX, tidy } from "./name.js";

// Stand-ins. The real list lives in Firestore and stays out of this
// repository, which is public; what is tested here is the matching, not the
// words.
const TERMS = ["badword", "ass"];

describe("checkShape", () => {
  test("accepts a name in any language the app speaks", () => {
    for (const name of [
      "새벽 질주자",
      "Dawn Runner",
      "夜明けの走者",
      "破晓奔跑者",
      "Corredor del Alba",
      "Coureur de l'Aube",
      "Läufer der Dämmerung",
      "Pelari Fajar",
    ]) {
      expect(checkShape(name), name).toBeNull();
    }
  });

  test("turns down a name too short or too long to be one", () => {
    expect(checkShape("   ")).toBe("blank");
    expect(checkShape("가")).toBe("tooShort");
    expect(checkShape("a".repeat(NAME_MAX + 1))).toBe("tooLong");
  });

  test("counts a character the way a reader does", () => {
    expect(checkShape("🇰🇷🇰🇷")).toBe("badCharacters");
    expect(checkShape("José García")).toBeNull();
  });

  test("leaves no way to type an address", () => {
    for (const name of ["oddlet.com", "http://x.kr", "@handle", "buy/now"]) {
      expect(checkShape(name), name).toBe("badCharacters");
    }
  });

  test("refuses a name that is only digits", () => {
    expect(checkShape("404")).toBe("badCharacters");
    expect(checkShape("Chick 404")).toBeNull();
  });

  test("refuses a character held down", () => {
    expect(checkShape("aaaaaaa")).toBe("repeats");
    expect(checkShape("aaa")).toBeNull();
  });

  test("tidies the same way the client does", () => {
    // Both copies exist so the field can object early; they have to agree, or
    // the app promises something the server then refuses.
    expect(tidy("  새벽  질주자  ")).toBe("새벽 질주자");
  });
});

describe("duplicateKey", () => {
  test("treats case, spacing and punctuation as the same name", () => {
    const key = duplicateKey("Dawn Runner");

    expect(duplicateKey("dawn-runner")).toBe(key);
    expect(duplicateKey("  DAWNRUNNER ")).toBe(key);
    expect(duplicateKey("dawn'runner")).toBe(key);
  });

  test("folds a full-width spelling onto the plain one", () => {
    expect(duplicateKey("Ｄａｗｎ")).toBe(duplicateKey("dawn"));
  });

  test("keeps genuinely different names apart", () => {
    expect(duplicateKey("Dawn Runner")).not.toBe(duplicateKey("Dusk Runner"));
  });
});

describe("isBlocked", () => {
  test("catches the word as typed", () => {
    expect(isBlocked("badword", TERMS)).toBe(true);
    expect(isBlocked("a badword here", TERMS)).toBe(true);
  });

  test("catches it spelled around the filter", () => {
    expect(isBlocked("b4dw0rd", TERMS)).toBe(true);
    expect(isBlocked("bаdword", TERMS)).toBe(true); // Cyrillic а
    expect(isBlocked("baaaadword", TERMS)).toBe(true);
    expect(isBlocked("ＢＡＤＷＯＲＤ", TERMS)).toBe(true);
    expect(isBlocked("bad-word", TERMS)).toBe(true);
  });

  test("matches a short term as a word and not inside one", () => {
    // Otherwise half the dictionary is refused, and a name turned down for no
    // visible reason is worse than one more entry in the list.
    expect(isBlocked("ass", TERMS)).toBe(true);
    expect(isBlocked("Casa Blanca", TERMS)).toBe(false);
    expect(isBlocked("Assassin", TERMS)).toBe(false);
  });

  test("leaves an ordinary name alone", () => {
    for (const name of ["Dawn Runner", "새벽 질주자", "Pintinho Comum"]) {
      expect(isBlocked(name, TERMS), name).toBe(false);
    }
  });

  test("an empty list blocks nothing", () => {
    expect(isBlocked("badword", [])).toBe(false);
  });
});
