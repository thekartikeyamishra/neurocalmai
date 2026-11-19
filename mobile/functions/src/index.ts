/* cSpell:disable */
/* eslint-disable max-len */
import * as crypto from "crypto";
import * as functions from "firebase-functions/v1";
import {setGlobalOptions} from "firebase-functions/v2";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onRequest, onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {google} from "googleapis";

import {bumpStats, db, ECONOMY, expiresInDays, FieldValue, PACKAGE_NAME, fail, requireUid} from "./common";
import {
  CBT_REFRAME_SYSTEM, GeminiContent, clip, crisisReply, generateWithFallback,
  isCrisisText, parseJsonLoose, refundAiCall, reserveAiCall, safeLanguage,
  therapySystemPrompt,
} from "./ai";
import {grantCredits} from "./wallet";
import {settleReferralIfPending} from "./referrals";

export {walletSync, walletSpend, claimAdReward, admobSsv} from "./wallet";
export {getReferralCode, redeemReferral} from "./referrals";
export {adminDashboard, adminLookupUser, adminGrantCredits} from "./admin";

// Cost guard-rail for every 2nd-gen function (prevents runaway scaling bills).
setGlobalOptions({maxInstances: 20});

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// ============================================================================
// 1. AI GATEWAY (v1, unchanged name/region so already-installed app versions
//    keep working). The server now owns model choice, input limits and quotas.
// ============================================================================
export const generateCBTReframe = functions
  .runWith({secrets: ["GEMINI_API_KEY"], timeoutSeconds: 60, memory: "256MB", maxInstances: 20})
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "User must be signed in.");
    }
    const uid = context.auth.uid;
    const userText = clip(data?.userText, 1200);
    if (!userText) {
      throw new functions.https.HttpsError("invalid-argument", "No valid user text provided.");
    }

    if (isCrisisText(userText)) {
      return {
        distortion: "none",
        reframe: String(crisisReply().reply),
        action: "Call a crisis line or a trusted person now. If you are in danger, call your local emergency number.",
        crisis: true,
      };
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError("internal", "Server configuration error.");
    }

    // Abuse ceilings only (this endpoint is already paid for by the tool flow).
    let reservation;
    try {
      reservation = await reserveAiCall(uid, false);
    } catch (e) {
      const err = e as HttpsError;
      throw new functions.https.HttpsError("resource-exhausted", err.message || "Please try again shortly.");
    }

    try {
      const text = await generateWithFallback(apiKey, {
        system: CBT_REFRAME_SYSTEM,
        contents: [{role: "user", parts: [{text: `<thought>${userText}</thought>`}]}],
        maxOutputTokens: 350,
        temperature: 0.4,
      });
      const parsed = parseJsonLoose(text);
      if (!parsed || typeof parsed.reframe !== "string") {
        throw new Error("Unparseable model output");
      }
      settleReferralIfPending(uid).catch(() => undefined);
      bumpStats({aiCalls: 1, aiReframes: 1});
      return {
        distortion: clip(parsed.distortion, 60) || "none",
        reframe: clip(parsed.reframe, 600),
        action: clip(parsed.action, 300) || "Take three slow breaths, longer out than in.",
      };
    } catch (error) {
      await refundAiCall(uid, reservation);
      console.error("[generateCBTReframe] failed:", (error as Error)?.message);
      const msg = (error as Error)?.message || "";
      if (error instanceof HttpsError && error.code === "resource-exhausted") {
        throw new functions.https.HttpsError("resource-exhausted", msg);
      }
      // Never leak provider URLs/keys to the client.
      throw new functions.https.HttpsError("unavailable", "The AI is temporarily unavailable. Please try again shortly.");
    }
  });

/**
 * Conversational CBT reply used by journals, chat and voice therapy.
 * Replaces the old client-side Gemini/OpenAI calls (keys no longer ship in
 * the APK). Metered: free daily allowance -> credits -> premium.
 */
export const aiTherapyReply = onCall(
  {secrets: [GEMINI_API_KEY], timeoutSeconds: 60, memory: "512MiB", maxInstances: 30},
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const message = clip(data.message, 1200);
    const language = safeLanguage(data.language);
    const audioBase64 = typeof data.audioBase64 === "string" ? data.audioBase64 : "";
    const audioMime = typeof data.audioMime === "string" && /^audio\/[a-z0-9.+-]{2,20}$/.test(data.audioMime) ? data.audioMime : "audio/mp4";

    if (!message && !audioBase64) fail("invalid-argument", "Please type or say what's on your mind.");
    // ~2.6 MB of base64 ≈ 2 minutes of AAC. Keeps cost and latency bounded.
    if (audioBase64.length > 2_600_000) fail("invalid-argument", "That recording is too long. Please keep it under 2 minutes.", "audio_too_long");

    if (message && isCrisisText(message)) {
      bumpStats({crisisFlags: 1});
      return {...crisisReply(), freeRemaining: null, balance: null};
    }

    const rawHistory = Array.isArray(data.history) ? data.history.slice(-4) : [];
    const contents: GeminiContent[] = [];
    for (const h of rawHistory) {
      const item = h as Record<string, unknown>;
      const text = clip(item?.content, 600);
      if (!text) continue;
      contents.push({role: item?.role === "user" ? "user" : "model", parts: [{text}]});
    }
    // Gemini requires the conversation to start with a user turn.
    while (contents.length > 0 && contents[0].role !== "user") contents.shift();

    if (audioBase64) {
      contents.push({role: "user", parts: [
        {inlineData: {mimeType: audioMime, data: audioBase64}},
        {text: "Transcribe what I said into the \"transcript\" field, then respond as instructed."},
      ]});
    } else {
      contents.push({role: "user", parts: [{text: message}]});
    }

    const reservation = await reserveAiCall(uid, true);
    try {
      const text = await generateWithFallback(GEMINI_API_KEY.value(), {
        system: therapySystemPrompt(language),
        contents,
        maxOutputTokens: 450,
        temperature: 0.5,
        timeoutMs: audioBase64 ? 40000 : 20000,
      });
      const parsed = parseJsonLoose(text) ?? {reply: clip(text, 800)};
      const transcript = clip(parsed.transcript, 1500);
      if (transcript && isCrisisText(transcript)) {
        return {...crisisReply(), transcript, freeRemaining: reservation.freeRemaining, balance: reservation.balance};
      }
      const features = (parsed.slm_features ?? {}) as Record<string, unknown>;
      settleReferralIfPending(uid).catch(() => undefined);
      bumpStats({
        aiCalls: 1, aiTherapy: 1, aiAudio: audioBase64 ? 1 : 0,
        aiFree: reservation.source === "free" ? 1 : 0, aiCredit: reservation.source === "credit" ? 1 : 0,
        aiPremium: reservation.source === "premium" ? 1 : 0,
      });
      return {
        reply: clip(parsed.reply, 900) || "I'm here with you. Tell me a little more?",
        transcript: transcript || undefined,
        slm_features: {
          detected_emotion: clip(features.detected_emotion, 30) || "neutral",
          cognitive_distortion: clip(features.cognitive_distortion, 40) || "none",
          urgency_level: clip(features.urgency_level, 10) || "low",
        },
        freeRemaining: reservation.freeRemaining,
        balance: reservation.balance,
        chargedWith: reservation.source,
      };
    } catch (e) {
      await refundAiCall(uid, reservation);
      bumpStats({aiErrors: 1});
      if (e instanceof HttpsError) throw e;
      console.error("[aiTherapyReply] failed", (e as Error)?.message);
      fail("unavailable", "The AI is temporarily unavailable. Your offline tools still work.", "ai_down");
    }
  },
);

// ============================================================================
// 2. SOMATIC GATEWAY: deterministic, zero AI cost.
// ============================================================================
export const generateSomaticRhythm = functions
  .runWith({maxInstances: 10})
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "User must be signed in.");
    }
    // Accept both the legacy and the current client field names.
    const bpmRaw = Number(data?.currentBpm ?? data?.bpm ?? 75);
    const currentBpm = Number.isFinite(bpmRaw) ? Math.min(220, Math.max(30, bpmRaw)) : 75;
    const tremor = Number(data?.tremor_freq ?? 0);
    const anxietyLevel = String(data?.anxietyLevel ?? (tremor > 6 ? "severe" : "moderate"));

    let rhythmName = "Box Breathing (4-4-4-4)";
    let instructions = "Inhale for 4, hold for 4, exhale for 4, hold for 4.";
    let hapticProfile = "medium";
    let rhythmPattern: number[] = [4, 4, 4, 4];

    if (currentBpm > 100 || anxietyLevel === "severe") {
      rhythmName = "4-7-8 Deep Pacing";
      instructions = "Inhale for 4, hold for 7, exhale slowly for 8.";
      hapticProfile = "high";
      rhythmPattern = [4, 7, 8];
    } else if (currentBpm < 65) {
      rhythmName = "Resonance Breathing";
      instructions = "Inhale for 5.5 seconds, exhale for 5.5 seconds.";
      hapticProfile = "low";
      rhythmPattern = [5.5, 5.5];
    }
    return {
      rhythmName, instructions, hapticProfile, rhythm_pattern: rhythmPattern,
      duration: 60, targetBpmReduction: currentBpm > 90 ? "15-20%" : "10%",
    };
  });

// ============================================================================
// 3. REVENUECAT WEBHOOK: idempotent, correct wallet path, no early revocation.
// ============================================================================
/**
 * Constant-time string comparison.
 * @param {string} a First.
 * @param {string} b Second.
 * @return {boolean} Equal.
 */
function safeEqual(a: string, b: string): boolean {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  return ab.length === bb.length && crypto.timingSafeEqual(ab, bb);
}

/**
 * Picks the Firebase uid from a RevenueCat event (skips anonymous RC ids).
 * @param {Record<string, unknown>} event RC event.
 * @return {string | null} uid.
 */
function resolveUid(event: Record<string, unknown>): string | null {
  const ids = [
    event.app_user_id, event.original_app_user_id,
    ...((Array.isArray(event.aliases) ? event.aliases : []) as unknown[]),
  ].filter((x): x is string => typeof x === "string" && x.length > 0);
  return ids.find((id) => !id.startsWith("$RCAnonymousID")) ?? null;
}

const SUBSCRIPTION_PRODUCT_HINTS = ["premium", "annual", "monthly", "quarterly", "lifetime"];

export const revenueCatWebhook = onRequest(
  {secrets: ["RC_WEBHOOK_SECRET"], maxInstances: 10},
  async (req, res) => {
    try {
      const webhookSecret = process.env.RC_WEBHOOK_SECRET || "";
      const authHeader = String(req.headers.authorization || "");
      if (!webhookSecret || !safeEqual(authHeader, `Bearer ${webhookSecret}`)) {
        res.status(401).send("Unauthorized");
        return;
      }
      const event = (req.body?.event ?? null) as Record<string, unknown> | null;
      if (!event || typeof event.type !== "string") {
        res.status(400).send("Invalid event data.");
        return;
      }
      const eventId = String(event.id || "");
      if (eventId) {
        try {
          await db.collection("rcEvents").doc(eventId).create({type: event.type, at: FieldValue.serverTimestamp(), expireAt: expiresInDays(90)});
        } catch {
          res.status(200).send("Duplicate ignored.");
          return;
        }
      }

      const type = event.type;
      const productId = String(event.product_id || "");
      const uid = resolveUid(event);

      if (type === "TRANSFER") {
        const to = (Array.isArray(event.transferred_to) ? event.transferred_to : []) as string[];
        const from = (Array.isArray(event.transferred_from) ? event.transferred_from : []) as string[];
        for (const id of from.filter((x) => !x.startsWith("$RCAnonymousID"))) {
          await db.collection("users").doc(id).set({isPremium: false, premiumUpdatedAt: FieldValue.serverTimestamp()}, {merge: true});
        }
        for (const id of to.filter((x) => !x.startsWith("$RCAnonymousID"))) {
          await db.collection("users").doc(id).set({isPremium: true, premiumUpdatedAt: FieldValue.serverTimestamp()}, {merge: true});
        }
        res.status(200).send("ok");
        return;
      }
      if (!uid) {
        res.status(200).send("No mappable user.");
        return;
      }
      const userRef = db.collection("users").doc(uid);
      const isSubscriptionProduct = SUBSCRIPTION_PRODUCT_HINTS.some((h) => productId.includes(h));
      const usd = Number(event.price ?? 0);
      if (["INITIAL_PURCHASE", "RENEWAL", "NON_RENEWING_PURCHASE"].includes(type) && Number.isFinite(usd) && usd > 0) {
        bumpStats({purchases: 1, revenueUsdCents: Math.round(usd * 100)});
      }
      if (type === "CANCELLATION") bumpStats({cancellations: 1});

      switch (type) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
      case "UNCANCELLATION":
      case "PRODUCT_CHANGE":
      case "SUBSCRIPTION_EXTENDED":
        if (isSubscriptionProduct) {
          await userRef.set({isPremium: true, premiumProduct: productId, premiumUpdatedAt: FieldValue.serverTimestamp()}, {merge: true});
        }
        break;
      case "CANCELLATION":
        // Auto-renew turned off: the user keeps access until EXPIRATION.
        await userRef.set({willRenew: false, premiumUpdatedAt: FieldValue.serverTimestamp()}, {merge: true});
        break;
      case "EXPIRATION":
        await userRef.set({isPremium: false, willRenew: false, premiumUpdatedAt: FieldValue.serverTimestamp()}, {merge: true});
        break;
      case "NON_RENEWING_PURCHASE": {
        if (productId.includes("lifetime")) {
          await userRef.set({isPremium: true, premiumProduct: productId, lifetime: true, premiumUpdatedAt: FieldValue.serverTimestamp()}, {merge: true});
          break;
        }
        let credits = 0;
        if (productId.startsWith("sachet_cbt_10")) credits = ECONOMY.creditsSachet10;
        else if (productId.startsWith("sachet_cbt_25")) credits = ECONOMY.creditsSachet25;
        if (credits > 0) await grantCredits(uid, credits, `purchase_${productId}`);
        break;
      }
      default:
        break;
      }
      res.status(200).send("Webhook processed successfully.");
    } catch (error) {
      console.error("Webhook Error:", error);
      res.status(500).send("Internal Server Error");
    }
  },
);

// ============================================================================
// 4. MODERATION ENGINE: Auto-Suspension (unchanged behaviour)
// ============================================================================
const SUSPENSION_THRESHOLD = 3;

export const processUGCReport = onDocumentCreated("reports/{reportId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const {contentId, contentType, reporterId} = snap.data();
  if (!contentId || !contentType || !reporterId) return;
  try {
    const reportsSnapshot = await db.collection("reports").where("contentId", "==", contentId).get();
    const uniqueReporters = new Set<string>();
    reportsSnapshot.forEach((doc) => uniqueReporters.add(doc.data().reporterId));
    if (uniqueReporters.size < SUSPENSION_THRESHOLD) return;

    if (contentType === "community") {
      await db.collection("communities").doc(contentId).update({status: "suspended", suspendedAt: FieldValue.serverTimestamp()});
    } else if (contentType === "event") {
      const eventsSnap = await db.collectionGroup("events").get();
      const batch = db.batch();
      let n = 0;
      eventsSnap.forEach((doc) => {
        if (doc.id === contentId) {
          batch.update(doc.ref, {status: "suspended", suspendedAt: FieldValue.serverTimestamp()});
          n++;
        }
      });
      if (n > 0) await batch.commit();
    } else if (contentType === "user") {
      await db.collection("users").doc(contentId).set({status: "under_review", flaggedAt: FieldValue.serverTimestamp()}, {merge: true});
    }
  } catch (error) {
    console.error("Moderation Error: ", error);
  }
});

// ============================================================================
// 5. PLAY INTEGRITY & DEVICE RECALL VERIFICATION (now requires sign-in)
// ============================================================================
export const verifyDeviceIntegrity = onCall(async (request) => {
  requireUid(request.auth?.uid);
  const {integrityToken, consumeTrial} = request.data ?? {};
  if (!integrityToken || typeof integrityToken !== "string") {
    throw new HttpsError("invalid-argument", "Missing integrityToken in request.");
  }
  try {
    const auth = new google.auth.GoogleAuth({scopes: ["https://www.googleapis.com/auth/playintegrity"]});
    const playIntegrity = google.playintegrity({version: "v1", auth});
    const decodeResponse = await playIntegrity.v1.decodeIntegrityToken({
      packageName: PACKAGE_NAME,
      requestBody: {integrityToken},
    });
    const payload = decodeResponse.data.tokenPayloadExternal;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const recallValues = (payload as any)?.deviceRecall?.values;
    const hasConsumedTrial = recallValues?.bit1 === true;
    if (consumeTrial && !hasConsumedTrial) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await (playIntegrity as any).deviceRecall.write({
        packageName: PACKAGE_NAME,
        requestBody: {integrityToken, newValues: {bit1: true, bit2: false, bit3: false}},
      });
    }
    return {
      isValidApp: payload?.requestDetails?.requestPackageName === PACKAGE_NAME,
      deviceVerdict: payload?.deviceIntegrity?.deviceRecognitionVerdict,
      appLicensingVerdict: payload?.accountDetails?.appLicensingVerdict,
      hasConsumedTrial: consumeTrial ? true : hasConsumedTrial,
    };
  } catch (error) {
    console.error("[Play Integrity Error]:", error);
    throw new HttpsError("internal", "Failed to verify Play Integrity token.");
  }
});

// ============================================================================
// 6. STUDIO DASHBOARD AGGREGATOR (B2B2C partners)
// ============================================================================
export const getStudioCohortStats = onCall(async (request) => {
  const callerId = requireUid(request.auth?.uid);
  const studioAffiliateId = String(request.data?.studioAffiliateId || "");
  if (!/^[A-Za-z0-9_-]{2,64}$/.test(studioAffiliateId)) {
    throw new HttpsError("invalid-argument", "Invalid studio id.");
  }
  const studioDoc = await db.collection("studios").doc(studioAffiliateId).get();
  if (!studioDoc.exists || studioDoc.data()?.managerUid !== callerId) {
    throw new HttpsError("permission-denied", "Unauthorized to view this cohort.");
  }
  const cohortSnap = await db.collection("users").where("affiliate_partner_id", "==", studioAffiliateId).get();
  let totalMembers = 0;
  let totalCbtSessions = 0;
  let totalStreakDays = 0;
  cohortSnap.forEach((doc) => {
    const d = doc.data();
    totalMembers++;
    totalCbtSessions += d.totalCbtSessions || 0;
    totalStreakDays += d.currentStreak || 0;
  });
  return {
    studioId: studioAffiliateId,
    activeMembers: totalMembers,
    averageCbtSessions: totalMembers > 0 ? Math.round(totalCbtSessions / totalMembers) : 0,
    averageStreakDays: totalMembers > 0 ? (totalStreakDays / totalMembers).toFixed(1) : 0,
    lastAggregated: new Date().toISOString(),
  };
});

// ============================================================================
// 7. ACCOUNT DELETION (Play Store + DPDP/GDPR "right to erasure")
// ============================================================================
export const deleteMyData = onCall({maxInstances: 10}, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const refs = [
    db.collection("wallets").doc(uid),
    db.collection("usage").doc(uid),
    db.collection("legal_consents").doc(uid),
    db.collection("offline_waitlist").doc(uid),
  ];
  await db.recursiveDelete(db.collection("users").doc(uid));
  await db.recursiveDelete(db.collection("wallets").doc(uid));
  const journals = await db.collection("journals").where("userId", "==", uid).get();
  const batch = db.batch();
  journals.forEach((d) => batch.delete(d.ref));
  refs.slice(1).forEach((r) => batch.delete(r));
  await batch.commit();
  try {
    await admin.auth().deleteUser(uid);
  } catch (e) {
    console.warn("[deleteMyData] auth delete failed", e);
  }
  return {ok: true};
});
