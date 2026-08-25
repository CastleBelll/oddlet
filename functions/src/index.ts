import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { checkShape, duplicateKey, isBlocked, tidy } from "./name.js";

initializeApp();
const db = getFirestore();

/** How many creatures a season holds. Mirrors CreatureAppearance.speciesCount. */
const SPECIES_COUNT = 288;

const REGION = "asia-northeast3";

/** Where the word list lives, so it can be changed without shipping an app. */
const WORDLIST = "moderation/wordlist";

/** How long an instance may reuse the word list it already fetched. */
const WORDLIST_TTL_MS = 5 * 60 * 1000;

let cachedTerms: readonly string[] = [];
let cachedAt = 0;

/**
 * Registers the name of a creature nobody has named yet.
 *
 * This is the only thing allowed to write a name. The client runs the same
 * shape checks so it can object while someone types, but it cannot be the one
 * to decide: this repository is public, so a filter shipped inside the app has
 * its word list read and its checks edited around.
 *
 * Naming is what creates the species document, so a species with no document
 * is a species with no name and the chance passes to whoever names it next.
 * Rules allow create and forbid update, which settles both who was first and
 * that nobody renames anything afterwards.
 */
export const registerName = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "sign in first");
  }
  // A name is shown to everyone who ever finds this creature. An anonymous
  // account cannot be answered for, so it does not get to write one.
  if (request.auth?.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("permission-denied", "connect a real account first");
  }

  const data = (request.data ?? {}) as Record<string, unknown>;
  const speciesId = readSpeciesId(data.speciesId);
  const name = tidy(String(data.name ?? ""));
  const handle = await settleHandle(uid, data.handle);

  reject(checkShape(name), "name");
  if (isBlocked(name, await wordList())) {
    throw new HttpsError("invalid-argument", "name:blocked");
  }

  const nameKey = duplicateKey(name);
  if (nameKey.length === 0) {
    throw new HttpsError("invalid-argument", "name:badCharacters");
  }

  const batch = db.batch();
  // Both creates, so both fail if either document already exists: the species
  // cannot be named twice and the name cannot be taken twice. Batched, so
  // there is never a claimed name with no species behind it.
  batch.create(db.doc(`speciesNames/${nameKey}`), { speciesId });
  batch.create(db.doc(`species/${speciesId}`), {
    name,
    nameKey,
    discovererUid: uid,
    discovererHandle: handle,
    namedAt: FieldValue.serverTimestamp(),
  });
  batch.set(db.doc(`users/${uid}`), { handle }, { merge: true });

  try {
    await batch.commit();
  } catch (error) {
    // ALREADY_EXISTS is the normal race, not a fault: somebody got there in
    // the seconds it took to type. Which document lost is worth saying, since
    // one means try another name and the other means it is over.
    if ((error as { code?: number }).code === 6) {
      const taken = await db.doc(`species/${speciesId}`).get();
      throw new HttpsError(
        "already-exists",
        taken.exists ? "species:named" : "name:taken",
      );
    }
    throw error;
  }

  return { name, handle };
});

function readSpeciesId(raw: unknown): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id < 0 || id >= SPECIES_COUNT) {
    throw new HttpsError("invalid-argument", "speciesId");
  }
  return id;
}

/**
 * The nickname this name is signed with.
 *
 * Kept apart from the Google account on purpose: the discoverer is shown to
 * strangers, and a real name does not belong there. Whoever already has one
 * keeps it; whoever does not picks one now, filtered the same way a creature
 * name is.
 */
async function settleHandle(uid: string, raw: unknown): Promise<string> {
  const existing = (await db.doc(`users/${uid}`).get()).get("handle");
  if (typeof existing === "string" && existing.length > 0) {
    return existing;
  }

  const handle = tidy(String(raw ?? ""));
  reject(checkShape(handle), "handle");
  if (isBlocked(handle, await wordList())) {
    throw new HttpsError("invalid-argument", "handle:blocked");
  }
  return handle;
}

function reject(problem: string | null, field: string): void {
  if (problem !== null) {
    throw new HttpsError("invalid-argument", `${field}:${problem}`);
  }
}

async function wordList(): Promise<readonly string[]> {
  const now = Date.now();
  if (now - cachedAt < WORDLIST_TTL_MS) {
    return cachedTerms;
  }

  const terms = (await db.doc(WORDLIST).get()).get("terms");
  // An unreadable list is not an excuse to wave a name through: it is the one
  // thing between a stranger's typing and everyone else's screen.
  if (!Array.isArray(terms)) {
    throw new HttpsError("unavailable", "naming is closed right now");
  }

  cachedTerms = terms.filter((term): term is string => typeof term === "string");
  cachedAt = now;
  return cachedTerms;
}
