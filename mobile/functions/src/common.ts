/* eslint-disable max-len */
import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const FieldValue = admin.firestore.FieldValue;
export const PACKAGE_NAME = "com.kartikeyamishra.mobile";

/**
 * Reads a positive integer from the environment (functions/.env) with a
 * safe fallback, so every economic lever can be tuned without a code change.
 * @param {string} name Environment variable name.
 * @param {number} fallback Value used when the variable is missing/invalid.
 * @return {number} The parsed value.
 */
export function intEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw.trim() === "") return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}

/**
 * Reads a boolean flag from the environment.
 * @param {string} name Environment variable name.
 * @param {boolean} fallback Default value.
 * @return {boolean} The flag.
 */
export function boolEnv(name: string, fallback: boolean): boolean {
  const raw = (process.env[name] || "").trim().toLowerCase();
  if (raw === "") return fallback;
  return raw === "true" || raw === "1" || raw === "yes";
}

/**
 * UTC calendar-day key used for daily allowances (YYYY-MM-DD).
 * @return {string} Today's key.
 */
export function todayKey(): string {
  return new Date().toISOString().slice(0, 10);
}

/** Central economic configuration. Every value is overridable via .env. */
export const ECONOMY = {
  // New wallets start with this many credits (old clients used 300).
  starterCredits: intEnv("STARTER_CREDITS", 20),
  // Free AI reflections per UTC day before credits are used.
  freeDailyAi: intEnv("FREE_DAILY_AI_CALLS", 5),
  // Abuse ceilings (not monetization) for any single account per day.
  hardDailyCapFree: intEnv("HARD_DAILY_CAP_FREE", 60),
  hardDailyCapPremium: intEnv("HARD_DAILY_CAP_PREMIUM", 250),
  burstPerMinute: intEnv("AI_BURST_PER_MINUTE", 6),
  // Rewarded ads.
  rewardCredits: intEnv("REWARDED_AD_CREDITS", 2),
  adsDailyCap: intEnv("REWARDED_ADS_DAILY_CAP", 15),
  adMinIntervalSeconds: intEnv("REWARDED_AD_MIN_INTERVAL_SECONDS", 20),
  requireSsv: boolEnv("REQUIRE_ADMOB_SSV", false),
  // Consumable packs (must match Play Console product titles).
  creditsSachet10: intEnv("CREDITS_SACHET_CBT_10", 10),
  creditsSachet25: intEnv("CREDITS_SACHET_CBT_25", 25),
  // Referrals.
  referralReceiverCredits: intEnv("REFERRAL_RECEIVER_CREDITS", 5),
  referralReferrerCredits: intEnv("REFERRAL_REFERRER_CREDITS", 5),
  referralMonthlyCap: intEnv("REFERRAL_MONTHLY_CAP", 30),
  referralMaxAccountAgeDays: intEnv("REFERRAL_MAX_ACCOUNT_AGE_DAYS", 14),
};

/**
 * Throws a structured, client-readable error.
 * @param {string} code Callable error code.
 * @param {string} message Human-readable message (safe to show).
 * @param {string} reason Machine-readable reason for the client.
 */
export function fail(
  code: "unauthenticated" | "invalid-argument" | "resource-exhausted" |
    "permission-denied" | "failed-precondition" | "internal" | "unavailable" |
    "not-found" | "already-exists",
  message: string,
  reason: string = code,
): never {
  throw new HttpsError(code, message, {reason});
}

/**
 * Returns the caller's uid or throws.
 * @param {string | undefined} uid uid from the callable context.
 * @return {string} uid.
 */
export function requireUid(uid: string | undefined): string {
  if (!uid) fail("unauthenticated", "Please restart the app to reconnect.");
  return uid;
}

/**
 * Reads whether a user currently holds premium (written by the webhook).
 * @param {admin.firestore.Transaction} tx Active transaction.
 * @param {string} uid User id.
 * @return {Promise<boolean>} Premium flag.
 */
export async function isPremiumInTx(
  tx: admin.firestore.Transaction,
  uid: string,
): Promise<boolean> {
  const snap = await tx.get(db.collection("users").doc(uid));
  return snap.exists && snap.get("isPremium") === true;
}

/**
 * Throws unless the caller has the `admin` custom claim. Admin accounts are
 * created by scripts/create-admin.mjs from environment variables, so no
 * credential is ever hard-coded in the app or the backend.
 * @param {{uid: string, token: Record<string, unknown>} | undefined} auth Callable auth.
 * @return {string} Admin uid.
 */
export function requireAdmin(auth: {uid: string; token: Record<string, unknown>} | undefined): string {
  if (!auth) fail("unauthenticated", "Sign in as an admin.");
  if (auth.token.admin !== true) fail("permission-denied", "Admin access required.");
  return auth.uid;
}

/**
 * Fire-and-forget daily counter for the admin dashboard. One small write per
 * event; never throws, never blocks the user path.
 * @param {Record<string, number>} fields Counters to increment.
 */
export function bumpStats(fields: Record<string, number>): void {
  const payload: Record<string, unknown> = {day: todayKey()};
  for (const [k, v] of Object.entries(fields)) {
    if (/^[a-zA-Z_]{1,40}$/.test(k) && Number.isFinite(v)) payload[k] = FieldValue.increment(v);
  }
  db.collection("stats").doc(todayKey()).set(payload, {merge: true}).catch(() => undefined);
}

/**
 * Timestamp N days from now, used with a Firestore TTL policy on `expireAt`
 * so bookkeeping documents delete themselves (storage never grows unbounded).
 * @param {number} days Days until expiry.
 * @return {admin.firestore.Timestamp} Expiry time.
 */
export function expiresInDays(days: number): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromMillis(Date.now() + days * 86400000);
}
