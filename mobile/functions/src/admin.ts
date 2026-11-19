/* eslint-disable max-len */
import * as admin from "firebase-admin";
import {onCall} from "firebase-functions/v2/https";
import {db, ECONOMY, FieldValue, fail, intEnv, requireAdmin} from "./common";
import {grantCredits} from "./wallet";

// Estimated blended AI cost per call in micro-dollars (default $0.0009).
// Update from real Google billing via AI_COST_PER_CALL_MICROUSD in .env.
const aiCostMicroUsd = (): number => intEnv("AI_COST_PER_CALL_MICROUSD", 900);

/** Company dashboard: daily counters, unit economics and live config. */
export const adminDashboard = onCall({maxInstances: 5}, async (request) => {
  requireAdmin(request.auth);
  const days = Math.min(60, Math.max(1, Number(request.data?.days) || 14));
  const snap = await db.collection("stats").orderBy("day", "desc").limit(days).get();
  const rows = snap.docs.map((d) => d.data() as Record<string, number | string>);
  const sum = (k: string): number => rows.reduce((a, r) => a + (Number(r[k]) || 0), 0);
  const aiCalls = sum("aiCalls");
  const aiCostUsd = (aiCalls * aiCostMicroUsd()) / 1e6;
  const revenueUsd = sum("revenueUsdCents") / 100;
  return {
    days: rows.reverse(),
    totals: {
      aiCalls, aiErrors: sum("aiErrors"), aiFree: sum("aiFree"), aiCredit: sum("aiCredit"),
      aiPremium: sum("aiPremium"), crisisFlags: sum("crisisFlags"),
      rewardedAds: sum("rewardedAds"), newWallets: sum("newWallets"),
      referralsRedeemed: sum("referralsRedeemed"), referralsSettled: sum("referralsSettled"),
      purchases: sum("purchases"), cancellations: sum("cancellations"),
      revenueUsd, aiCostUsdEstimate: Number(aiCostUsd.toFixed(2)),
      aiErrorRate: aiCalls > 0 ? Number((sum("aiErrors") / aiCalls).toFixed(4)) : 0,
    },
    note: "Ad revenue lives in AdMob; subscription revenue here is from RevenueCat webhooks (gross, before store fees).",
    economy: ECONOMY,
    modelChain: (process.env.AI_MODEL_CHAIN || "gemini-3.5-flash-lite,gemini-3.1-flash-lite,gemini-3.5-flash"),
  };
});

/** Support tool: look up one user by uid or referral code. */
export const adminLookupUser = onCall({maxInstances: 5}, async (request) => {
  requireAdmin(request.auth);
  let uid = String(request.data?.uid || "").trim();
  const code = String(request.data?.referralCode || "").trim().toUpperCase();
  if (!uid && code) {
    const c = await db.collection("referralCodes").doc(code).get();
    uid = String(c.get("uid") || "");
  }
  if (!/^[A-Za-z0-9]{10,128}$/.test(uid)) fail("invalid-argument", "Provide a valid uid or referral code.");
  const [authUser, wallet, usage, user, ledger] = await Promise.all([
    admin.auth().getUser(uid).catch(() => null),
    db.collection("wallets").doc(uid).get(),
    db.collection("usage").doc(uid).get(),
    db.collection("users").doc(uid).get(),
    db.collection("wallets").doc(uid).collection("ledger").orderBy("at", "desc").limit(10).get(),
  ]);
  if (!authUser && !wallet.exists) fail("not-found", "No such user.");
  const u = user.data() ?? {};
  return {
    uid,
    auth: authUser ? {
      anonymous: authUser.providerData.length === 0,
      created: authUser.metadata.creationTime,
      lastSignIn: authUser.metadata.lastSignInTime,
      disabled: authUser.disabled,
    } : null,
    wallet: {balance: Number(wallet.get("balance") || 0)},
    usage: usage.exists ? {
      day: usage.get("day"), freeUsed: usage.get("freeUsed"), dayCount: usage.get("dayCount"),
      total: usage.get("total"), adsToday: usage.get("adsCount"),
    } : null,
    profile: {
      isPremium: u.isPremium === true, premiumProduct: u.premiumProduct ?? null,
      willRenew: u.willRenew ?? null, referralCode: u.referralCode ?? null,
      referredBy: u.referredBy ?? null, successfulReferrals: u.successfulReferrals ?? 0,
      status: u.status ?? "active",
    },
    ledger: ledger.docs.map((d) => ({delta: d.get("delta"), reason: d.get("reason"), at: d.get("at")?.toDate?.()?.toISOString?.() ?? null})),
  };
});

/** Support tool: goodwill / make-good credits, fully audited. */
export const adminGrantCredits = onCall({maxInstances: 5}, async (request) => {
  const adminUid = requireAdmin(request.auth);
  const uid = String(request.data?.uid || "").trim();
  const amount = Number(request.data?.amount);
  const reason = String(request.data?.reason || "support").slice(0, 80);
  if (!/^[A-Za-z0-9]{10,128}$/.test(uid)) fail("invalid-argument", "Invalid uid.");
  if (!Number.isInteger(amount) || amount < 1 || amount > 500) fail("invalid-argument", "Amount must be 1-500.");
  const balance = await grantCredits(uid, amount, `admin:${reason}`);
  await db.collection("adminAudit").add({
    adminUid, action: "grantCredits", uid, amount, reason, at: FieldValue.serverTimestamp(),
  });
  return {ok: true, balance};
});
