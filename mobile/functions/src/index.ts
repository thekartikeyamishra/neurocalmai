/* cSpell:disable */
/* eslint-disable no-trailing-spaces */
/* eslint-disable eol-last */
/* eslint-disable padded-blocks */
/* eslint-disable max-len */
/* eslint-disable object-curly-spacing */

import * as functions from "firebase-functions/v1";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import {
  onRequest,
  onCall,
  HttpsError as HttpsErrorV2,
} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { google } from "googleapis";

admin.initializeApp();
const db = admin.firestore();

// Ensure this matches the package name registered in your Google Play Console
const PACKAGE_NAME = "com.kartikeyamishra.mobile";

// ============================================================================
// 1. AI GATEWAY: Cognitive Behavioral Therapy Pipeline
// ============================================================================
export const generateCBTReframe = functions
  .runWith({ secrets: ["GEMINI_API_KEY"] })
  .https.onCall(async (data, context) => {
    // Authentication Security
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be signed in.",
      );
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError(
        "internal",
        "Server configuration error.",
      );
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const userText = data.userText;

    // Intercept deprecated models and force upgrade to 3.5-flash
    let modelName = data.model || "gemini-3.5-flash";
    if (modelName.includes("1.5") || modelName.includes("2.0")) {
      modelName = "gemini-3.5-flash";
    }

    if (!userText || typeof userText !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "No valid user text provided.",
      );
    }

    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const prompt = `
        You are NeuroCalm, a highly empathetic Cognitive Behavioral Therapy (CBT) assistant. 
        Analyze the following anxious thought or feeling: "${userText}"
        Provide a response in strict JSON format with exactly these three keys:
        {
          "distortion": "Name of the primary cognitive distortion (e.g., Catastrophizing) or 'none'",
          "reframe": "A gentle, empathetic 2-sentence reframe of the thought",
          "action": "One small, immediate grounding action step"
        }
        Do not include markdown blocks in the output.
      `;

      const result = await model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      const cleanJson = text
        .replace(/```json/gi, "")
        .replace(/```/g, "")
        .trim();
      return JSON.parse(cleanJson);

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } catch (error: any) {
      console.error("Gemini API Error:", error);

      const errorMessage = error.message || "";

      // 🚨 FIX: Gracefully intercept billing/quota errors so raw URLs do not bleed into the UI.
      // Translates to a polite "High Traffic" message on the Flutter client.
      if (
        errorMessage.includes("429") ||
        errorMessage.includes("credits are depleted") ||
        errorMessage.includes("quota")
      ) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "The AI service is currently experiencing high traffic or resource limits. Please try again shortly.",
        );
      }

      throw new functions.https.HttpsError(
        "internal",
        `AI Generation Failed: ${error.message}`,
      );
    }
  });

// ============================================================================
// 2. SOMATIC GATEWAY: Grounding Rhythm Generator
// ============================================================================
export const generateSomaticRhythm = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be signed in.",
      );
    }

    const currentBpm = data.currentBpm;
    const anxietyLevel = data.anxietyLevel;

    let assignedRhythm = "Box Breathing (4-4-4-4)";
    let description = "Inhale for 4, hold for 4, exhale for 4, hold for 4.";
    let hapticIntensity = "medium";
    let rhythmPattern = [4, 4, 4, 4];

    // Dynamic overrides based on biometric baseline
    if (currentBpm > 100 || anxietyLevel === "severe") {
      assignedRhythm = "4-7-8 Deep Pacing";
      description =
        "Inhale for 4, hold for 7, forcefully exhale for 8 to rapidly lower heart rate.";
      hapticIntensity = "high";
      rhythmPattern = [4, 7, 8];
    } else if (currentBpm < 65) {
      assignedRhythm = "Resonance Breathing";
      description =
        "Inhale for 5.5 seconds, exhale for 5.5 seconds to maximize HRV.";
      hapticIntensity = "low";
      rhythmPattern = [5.5, 5.5];
    }

    return {
      rhythmName: assignedRhythm,
      instructions: description,
      hapticProfile: hapticIntensity,
      rhythm_pattern: rhythmPattern,
      duration: 60,
      targetBpmReduction: currentBpm > 90 ? "15-20%" : "10%",
    };
  },
);

// ============================================================================
// 3. REVENUECAT WEBHOOK: Monetization Sync
// ============================================================================
export const revenueCatWebhook = onRequest(
  { secrets: ["RC_WEBHOOK_SECRET"], maxInstances: 10 },
  async (req, res) => {
    try {
      const webhookSecret = process.env.RC_WEBHOOK_SECRET || "";
      const authHeader = req.headers.authorization;

      if (authHeader !== `Bearer ${webhookSecret}`) {
        res.status(401).send("Unauthorized");
        return;
      }

      const event = req.body?.event;
      if (!event || !event.app_user_id) {
        res.status(400).send("Invalid event data.");
        return;
      }

      const {
        type: eventType,
        app_user_id: appUserId,
        product_id: productId,
      } = event;
      const userRef = db.collection("users").doc(appUserId);

      if (eventType === "INITIAL_PURCHASE" || eventType === "RENEWAL") {
        if (
          productId.includes("premium") ||
          productId.includes("annual") ||
          productId.includes("quarterly")
        ) {
          await userRef.set(
            {
              isPremium: true,
              premiumUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }
      } else if (eventType === "CANCELLATION" || eventType === "EXPIRATION") {
        await userRef.set(
          {
            isPremium: false,
            premiumUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      } else if (eventType === "NON_RENEWING_PURCHASE") {
        let creditsToAdd = 0;
        if (productId === "sachet_cbt_10") creditsToAdd = 10;
        else if (productId === "sachet_cbt_25") creditsToAdd = 25;

        if (creditsToAdd > 0) {
          await userRef.set(
            {
              walletBalance: admin.firestore.FieldValue.increment(creditsToAdd),
              lastTopUpAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }
      }

      res.status(200).send("Webhook processed successfully.");
    } catch (error) {
      console.error("Webhook Error:", error);
      res.status(500).send("Internal Server Error");
    }
  },
);

// ============================================================================
// 4. MODERATION ENGINE: Auto-Suspension
// ============================================================================
const SUSPENSION_THRESHOLD = 3;

export const processUGCReport = onDocumentCreated(
  "reports/{reportId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const { contentId, contentType, reporterId } = snap.data();
    if (!contentId || !contentType || !reporterId) return;

    try {
      const reportsSnapshot = await db
        .collection("reports")
        .where("contentId", "==", contentId)
        .get();

      const uniqueReporters = new Set<string>();
      reportsSnapshot.forEach((doc) =>
        uniqueReporters.add(doc.data().reporterId),
      );

      if (uniqueReporters.size >= SUSPENSION_THRESHOLD) {
        if (contentType === "community") {
          await db.collection("communities").doc(contentId).update({
            status: "suspended",
            suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else if (contentType === "event") {
          const eventsSnap = await db
            .collectionGroup("events")
            .where(admin.firestore.FieldPath.documentId(), "==", contentId)
            .get();

          if (!eventsSnap.empty) {
            const batch = db.batch();
            eventsSnap.forEach((doc) => {
              batch.update(doc.ref, {
                status: "suspended",
                suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            });
            await batch.commit();
          }
        } else if (contentType === "user") {
          await db.collection("users").doc(contentId).update({
            status: "under_review",
            flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (error) {
      console.error("Moderation Error: ", error);
    }
  },
);

// ============================================================================
// 5. PLAY INTEGRITY & DEVICE RECALL VERIFICATION
// ============================================================================
export const verifyDeviceIntegrity = onCall(async (request) => {
  const { integrityToken, consumeTrial } = request.data;

  if (!integrityToken) {
    throw new HttpsErrorV2(
      "invalid-argument",
      "Missing integrityToken in request.",
    );
  }

  try {
    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/playintegrity"],
    });

    // Fix for ts(2769): Pass the GoogleAuth instance directly to the auth parameter.
    // The googleapis library handles the client resolution internally.
    const playIntegrity = google.playintegrity({
      version: "v1",
      auth: auth,
    });

    // Decode the token on Google's servers
    const decodeResponse = await playIntegrity.v1.decodeIntegrityToken({
      packageName: PACKAGE_NAME,
      requestBody: { integrityToken },
    });

    const payload = decodeResponse.data.tokenPayloadExternal;

    // Fix for ts(2339): The Device Recall feature is in beta and its typings may not be 
    // immediately available in standard @types/googleapis. We assert 'any' to safely read it.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const recallValues = (payload as any)?.deviceRecall?.values;
    const hasConsumedTrial = recallValues?.bit1 === true;

    // If the client is requesting to consume the trial now, write to Device Recall
    if (consumeTrial && !hasConsumedTrial) {
      // Cast as `any` safely to handle beta endpoint typings in standard googleapis packages
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await (playIntegrity as any).deviceRecall.write({
        packageName: PACKAGE_NAME,
        requestBody: {
          integrityToken: integrityToken,
          newValues: {
            bit1: true,
            bit2: false,
            bit3: false,
          },
        },
      });
      console.info("[Device Recall]: Trial consumed for device.");
    }

    return {
      isValidApp: payload?.requestDetails?.requestPackageName === PACKAGE_NAME,
      deviceVerdict: payload?.deviceIntegrity?.deviceRecognitionVerdict,
      appLicensingVerdict: payload?.accountDetails?.appLicensingVerdict,
      hasConsumedTrial: consumeTrial ? true : hasConsumedTrial,
    };
  } catch (error) {
    console.error("[Play Integrity Error]:", error);
    throw new HttpsErrorV2(
      "internal",
      "Failed to verify Play Integrity token.",
    );
  }
});

// ============================================================================
// 6. STUDIO DASHBOARD AGGREGATOR
// ============================================================================
export const getStudioCohortStats = onCall(async (request) => {
  const { studioAffiliateId } = request.data;

  if (!request.auth) {
    throw new HttpsErrorV2(
      "unauthenticated",
      "You must be signed in to view dashboard data.",
    );
  }

  // 1. Verify caller has permission to view this specific studio's data
  const callerId = request.auth.uid;
  const studioDoc = await db.collection("studios").doc(studioAffiliateId).get();

  if (!studioDoc.exists || studioDoc.data()?.managerUid !== callerId) {
    throw new HttpsErrorV2(
      "permission-denied",
      "Unauthorized to view this cohort.",
    );
  }

  // 2. Aggregate anonymous metrics for all users who used this studio's referral code.
  const cohortSnap = await db
    .collection("users")
    .where("affiliate_partner_id", "==", studioAffiliateId)
    .get();

  let totalMembers = 0;
  let totalCbtSessions = 0;
  let totalStreakDays = 0;

  cohortSnap.forEach((doc) => {
    const data = doc.data();
    totalMembers++;
    totalCbtSessions += data.totalCbtSessions || 0;
    totalStreakDays += data.currentStreak || 0;
  });

  return {
    studioId: studioAffiliateId,
    activeMembers: totalMembers,
    averageCbtSessions:
      totalMembers > 0 ? Math.round(totalCbtSessions / totalMembers) : 0,
    averageStreakDays:
      totalMembers > 0 ? (totalStreakDays / totalMembers).toFixed(1) : 0,
    lastAggregated: new Date().toISOString(),
  };
});