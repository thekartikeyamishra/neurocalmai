/* eslint-disable max-len */
import * as crypto from "crypto";
import * as admin from "firebase-admin";
import {onCall} from "firebase-functions/v2/https";
import {bumpStats, db, ECONOMY, FieldValue, fail, requireUid} from "./common";
import {grantCredits} from "./wallet";

// No 0/O/1/I/L to avoid typos when codes are read aloud or typed.
const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_RE = /^[A-Z2-9]{6,8}$/;

/**
 * Generates a random, human-friendly referral code.
 * @return {string} 7-character code.
 */
function randomCode(): string {
  const bytes = crypto.randomBytes(7);
  let out = "";
  for (let i = 0; i < 7; i++) out += ALPHABET[bytes[i] % ALPHABET.length];
  return out;
}

/** Returns (creating once) the caller's referral code. */
export const getReferralCode = onCall({maxInstances: 10}, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const userRef = db.collection("users").doc(uid);
  const existing = await userRef.get();
  const current = existing.get("referralCode");
  if (typeof current === "string" && CODE_RE.test(current)) {
    return {code: current, receiverCredits: ECONOMY.referralReceiverCredits, referrerCredits: ECONOMY.referralReferrerCredits};
  }
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = randomCode();
    const codeRef = db.collection("referralCodes").doc(code);
    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(codeRef);
        if (snap.exists) throw new Error("collision");
        tx.set(codeRef, {uid, createdAt: FieldValue.serverTimestamp()});
        tx.set(userRef, {referralCode: code}, {merge: true});
      });
      return {code, receiverCredits: ECONOMY.referralReceiverCredits, referrerCredits: ECONOMY.referralReferrerCredits};
    } catch (e) {
      if ((e as Error).message !== "collision") throw e;
    }
  }
  fail("internal", "Could not create an invite code. Please try again.");
});

/**
 * Redeems a friend's code. The receiver gets credits now; the referrer is
 * paid only after the receiver completes a first AI session (anti-farming).
 */
export const redeemReferral = onCall({maxInstances: 10}, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const code = String(request.data?.code || "").trim().toUpperCase();
  if (!CODE_RE.test(code)) return {ok: false, message: "That invite code doesn't look right."};

  const user = await admin.auth().getUser(uid);
  const createdMs = Date.parse(user.metadata.creationTime || "");
  const ageDays = Number.isFinite(createdMs) ? (Date.now() - createdMs) / 86400000 : 999;
  if (ageDays > ECONOMY.referralMaxAccountAgeDays) {
    return {ok: false, message: "Invite codes work for new members only."};
  }

  const codeRef = db.collection("referralCodes").doc(code);
  const receiverRef = db.collection("users").doc(uid);
  const monthKey = new Date().toISOString().slice(0, 7);

  const outcome = await db.runTransaction(async (tx) => {
    const [codeSnap, receiverSnap] = await Promise.all([tx.get(codeRef), tx.get(receiverRef)]);
    if (!codeSnap.exists) return {ok: false, message: "Invite code not found."};
    const referrerUid = String(codeSnap.get("uid") || "");
    if (!referrerUid || referrerUid === uid) return {ok: false, message: "You can't use your own invite code."};
    if (receiverSnap.exists && receiverSnap.get("referredBy")) {
      return {ok: false, message: "You've already used an invite code."};
    }
    const referrerRef = db.collection("users").doc(referrerUid);
    const referrerSnap = await tx.get(referrerRef);
    const monthCount = referrerSnap.get("referralMonth") === monthKey ? Number(referrerSnap.get("referralMonthCount") || 0) : 0;
    const referrerCapped = monthCount >= ECONOMY.referralMonthlyCap;
    tx.set(receiverRef, {
      referredBy: referrerUid,
      referralCodeUsed: code,
      referralPendingFor: referrerCapped ? null : referrerUid,
      referredAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.set(referrerRef, {
      referralMonth: monthKey,
      referralMonthCount: monthCount + 1,
      totalReferrals: FieldValue.increment(1),
    }, {merge: true});
    return {ok: true, message: ""};
  });

  if (!outcome.ok) return outcome;
  const balance = await grantCredits(uid, ECONOMY.referralReceiverCredits, "referral_receiver");
  bumpStats({referralsRedeemed: 1});
  return {
    ok: true,
    balance,
    message: `Welcome gift unlocked: +${ECONOMY.referralReceiverCredits} credits.`,
  };
});

/**
 * Pays the referrer once the referred user has really used the product.
 * Called after a successful AI response. Never throws.
 * @param {string} uid The referred user's id.
 */
export async function settleReferralIfPending(uid: string): Promise<void> {
  try {
    const ref = db.collection("users").doc(uid);
    const referrerUid = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const pending = snap.exists ? snap.get("referralPendingFor") : null;
      if (typeof pending !== "string" || !pending) return null;
      tx.set(ref, {referralPendingFor: null, referralSettledAt: FieldValue.serverTimestamp()}, {merge: true});
      return pending;
    });
    if (referrerUid) {
      await grantCredits(referrerUid, ECONOMY.referralReferrerCredits, "referral_referrer");
      bumpStats({referralsSettled: 1});
      await db.collection("users").doc(referrerUid).set({
        successfulReferrals: FieldValue.increment(1),
      }, {merge: true});
    }
  } catch (e) {
    console.error("[Referral] settle failed", e);
  }
}
