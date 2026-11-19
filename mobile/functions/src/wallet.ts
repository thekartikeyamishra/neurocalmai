/* eslint-disable max-len */
import * as crypto from "crypto";
import * as admin from "firebase-admin";
import {onCall, onRequest} from "firebase-functions/v2/https";
import {bumpStats, db, ECONOMY, expiresInDays, FieldValue, fail, requireUid, todayKey} from "./common";

const NONCE_RE = /^[A-Za-z0-9_-]{8,64}$/;
const REQUEST_ID_RE = /^[A-Za-z0-9_-]{6,64}$/;

/**
 * Inside a transaction: returns the wallet balance, creating the wallet with
 * starter credits if it does not exist yet. Must be called before any writes.
 * @param {admin.firestore.Transaction} tx Transaction.
 * @param {string} uid User id.
 * @return {Promise<{balance: number, exists: boolean}>} Wallet state.
 */
async function readWallet(tx: admin.firestore.Transaction, uid: string): Promise<{balance: number; exists: boolean}> {
  const snap = await tx.get(db.collection("wallets").doc(uid));
  if (!snap.exists) return {balance: ECONOMY.starterCredits, exists: false};
  return {balance: Math.max(0, Number(snap.get("balance") || 0)), exists: true};
}

/**
 * Writes a new absolute wallet balance inside a transaction.
 * @param {admin.firestore.Transaction} tx Transaction.
 * @param {string} uid User id.
 * @param {number} balance New balance.
 * @param {boolean} exists Whether the wallet already exists.
 */
function writeWallet(tx: admin.firestore.Transaction, uid: string, balance: number, exists: boolean): void {
  const ref = db.collection("wallets").doc(uid);
  const payload: Record<string, unknown> = {balance, updatedAt: FieldValue.serverTimestamp()};
  if (!exists) payload.createdAt = FieldValue.serverTimestamp();
  tx.set(ref, payload, {merge: true});
}

/**
 * Adds credits atomically (used by purchases, referrals, rewards).
 * @param {string} uid User id.
 * @param {number} amount Credits to add (> 0).
 * @param {string} reason Ledger reason.
 * @return {Promise<number>} New balance.
 */
export async function grantCredits(uid: string, amount: number, reason: string): Promise<number> {
  if (amount <= 0) return 0;
  return db.runTransaction(async (tx) => {
    const w = await readWallet(tx, uid);
    const next = w.balance + amount;
    writeWallet(tx, uid, next, w.exists);
    tx.set(db.collection("wallets").doc(uid).collection("ledger").doc(), {
      delta: amount, reason, at: FieldValue.serverTimestamp(),
    });
    return next;
  });
}

/**
 * Credits one rewarded-ad view, idempotent per (uid, nonce). Both the client
 * claim and the AdMob SSV callback route here, so a reward is never paid twice.
 * @param {string} uid User id.
 * @param {string} nonce Client-generated nonce passed as SSV custom data.
 * @param {"client" | "ssv"} via Which path is crediting.
 * @return {Promise<object>} Outcome with credited flag and balance.
 */
export async function creditAdReward(uid: string, nonce: string, via: "client" | "ssv"): Promise<{credited: boolean; balance: number; reason?: string}> {
  const claimRef = db.collection("adClaims").doc(`${uid}_${nonce}`);
  const usageRef = db.collection("usage").doc(uid);
  const today = todayKey();
  return db.runTransaction(async (tx) => {
    const [claimSnap, usageSnap] = await Promise.all([tx.get(claimRef), tx.get(usageRef)]);
    const w = await readWallet(tx, uid);
    if (claimSnap.exists) return {credited: false, balance: w.balance, reason: "duplicate"};

    const u = usageSnap.exists ? usageSnap.data() ?? {} : {};
    const adsToday = u.adsDay === today ? Number(u.adsCount || 0) : 0;
    const lastAdAt = Number(u.lastAdAtMs || 0);
    if (adsToday >= ECONOMY.adsDailyCap) {
      return {credited: false, balance: w.balance, reason: "daily_cap"};
    }
    if (via === "client" && Date.now() - lastAdAt < ECONOMY.adMinIntervalSeconds * 1000) {
      return {credited: false, balance: w.balance, reason: "too_fast"};
    }
    const next = w.balance + ECONOMY.rewardCredits;
    writeWallet(tx, uid, next, w.exists);
    tx.set(claimRef, {uid, nonce, via, credits: ECONOMY.rewardCredits, at: FieldValue.serverTimestamp(), expireAt: expiresInDays(30)});
    tx.set(usageRef, {adsDay: today, adsCount: adsToday + 1, lastAdAtMs: Date.now()}, {merge: true});
    return {credited: true, balance: next};
  }).then((r) => {
    if (r.credited) bumpStats({rewardedAds: 1, creditsFromAds: ECONOMY.rewardCredits});
    return r;
  });
}

// ============================================================================
// CALLABLES
// ============================================================================

/** Creates the wallet if needed and returns the economy snapshot for the UI. */
export const walletSync = onCall({maxInstances: 20}, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const today = todayKey();
  const result = await db.runTransaction(async (tx) => {
    const usageRef = db.collection("usage").doc(uid);
    const userRef = db.collection("users").doc(uid);
    const [usageSnap, userSnap] = await Promise.all([tx.get(usageRef), tx.get(userRef)]);
    const w = await readWallet(tx, uid);
    if (!w.exists) {
      writeWallet(tx, uid, w.balance, false);
      bumpStats({newWallets: 1});
    }
    const isPremium = userSnap.exists && userSnap.get("isPremium") === true;
    const freeUsed = usageSnap.exists && usageSnap.get("day") === today ? Number(usageSnap.get("freeUsed") || 0) : 0;
    return {balance: w.balance, isPremium, freeUsed};
  });
  return {
    balance: result.balance,
    isPremium: result.isPremium,
    freeDaily: ECONOMY.freeDailyAi,
    freeRemaining: result.isPremium ? 999 : Math.max(0, ECONOMY.freeDailyAi - result.freeUsed),
    rewardCredits: ECONOMY.rewardCredits,
    requireSsv: ECONOMY.requireSsv,
  };
});

/** Spends credits for a premium tool. Idempotent per requestId. */
export const walletSpend = onCall({maxInstances: 20}, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const amount = Number(request.data?.amount);
  const requestId = String(request.data?.requestId || "");
  const reason = String(request.data?.reason || "tool").slice(0, 40);
  if (!Number.isInteger(amount) || amount < 1 || amount > 10) fail("invalid-argument", "Invalid amount.");
  if (!REQUEST_ID_RE.test(requestId)) fail("invalid-argument", "Invalid request.");

  const spendRef = db.collection("wallets").doc(uid).collection("ledger").doc(`spend_${requestId}`);
  return db.runTransaction(async (tx) => {
    const [spendSnap, userSnap] = await Promise.all([
      tx.get(spendRef), tx.get(db.collection("users").doc(uid)),
    ]);
    const w = await readWallet(tx, uid);
    if (spendSnap.exists) return {ok: true, balance: w.balance, duplicate: true};
    if (userSnap.exists && userSnap.get("isPremium") === true) {
      return {ok: true, balance: w.balance, premium: true};
    }
    if (w.balance < amount) return {ok: false, balance: w.balance, reason: "credits"};
    const next = w.balance - amount;
    writeWallet(tx, uid, next, w.exists);
    tx.set(spendRef, {delta: -amount, reason, at: FieldValue.serverTimestamp()});
    return {ok: true, balance: next};
  });
});

/** Client-side claim after onUserEarnedReward. Capped and idempotent. */
export const claimAdReward = onCall({maxInstances: 20}, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const nonce = String(request.data?.nonce || "");
  if (!NONCE_RE.test(nonce)) fail("invalid-argument", "Invalid reward token.");
  if (ECONOMY.requireSsv) {
    // Credit arrives from AdMob's server callback; tell the client to listen.
    const snap = await db.collection("adClaims").doc(`${uid}_${nonce}`).get();
    const wallet = await db.collection("wallets").doc(uid).get();
    return {
      credited: snap.exists, pending: !snap.exists,
      balance: Number(wallet.get("balance") || 0), credits: ECONOMY.rewardCredits,
    };
  }
  const r = await creditAdReward(uid, nonce, "client");
  return {...r, credits: ECONOMY.rewardCredits};
});

// ============================================================================
// ADMOB SERVER-SIDE VERIFICATION (SSV)
// Configure in AdMob > Ad unit (rewarded) > Server-side verification:
//   https://us-central1-<project>.cloudfunctions.net/admobSsv
// ============================================================================
let keyCache: {fetchedAt: number; keys: Map<string, string>} | null = null;

/**
 * Fetches and caches Google's AdMob SSV public keys (24h).
 * @return {Promise<Map<string, string>>} keyId -> PEM.
 */
async function verifierKeys(): Promise<Map<string, string>> {
  if (keyCache && Date.now() - keyCache.fetchedAt < 24 * 3600 * 1000) return keyCache.keys;
  const res = await fetch("https://www.gstatic.com/admob/reward/verifier-keys.json");
  if (!res.ok) throw new Error(`verifier keys HTTP ${res.status}`);
  const json = (await res.json()) as {keys?: Array<{keyId: number | string; pem: string}>};
  const keys = new Map<string, string>();
  for (const k of json.keys ?? []) keys.set(String(k.keyId), k.pem);
  keyCache = {fetchedAt: Date.now(), keys};
  return keys;
}

export const admobSsv = onRequest({maxInstances: 10}, async (req, res) => {
  try {
    const query = (req.originalUrl || req.url || "").split("?")[1] || "";
    const sigIndex = query.indexOf("&signature=");
    if (!query || sigIndex < 0) {
      // AdMob's "Verify URL" button pings without a signature.
      res.status(200).send("ok");
      return;
    }
    const content = query.slice(0, sigIndex);
    const params = new URLSearchParams(query);
    const signature = params.get("signature") || "";
    const keyId = params.get("key_id") || "";
    const pem = (await verifierKeys()).get(keyId);
    if (!pem) {
      keyCache = null; // force refresh next time (key rotation)
      res.status(400).send("unknown key");
      return;
    }
    const valid = crypto.verify(
      "sha256", Buffer.from(content), {key: pem}, Buffer.from(signature, "base64url"),
    );
    if (!valid) {
      res.status(400).send("bad signature");
      return;
    }
    const uid = params.get("user_id") || "";
    const nonce = params.get("custom_data") || "";
    const transactionId = params.get("transaction_id") || "";
    if (!uid || !NONCE_RE.test(nonce)) {
      res.status(200).send("ignored");
      return;
    }
    // Ensure the uid is real before crediting (prevents crediting junk ids).
    try {
      await admin.auth().getUser(uid);
    } catch {
      res.status(200).send("unknown user");
      return;
    }
    await db.collection("ssv").doc(transactionId || `${uid}_${nonce}`).set({
      uid, nonce, adUnit: params.get("ad_unit") || "", at: FieldValue.serverTimestamp(), expireAt: expiresInDays(30),
    }, {merge: true});
    await creditAdReward(uid, nonce, "ssv");
    res.status(200).send("ok");
  } catch (e) {
    console.error("[SSV] error", e);
    res.status(500).send("error");
  }
});
