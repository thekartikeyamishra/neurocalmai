/* eslint-disable no-trailing-spaces */
/* eslint-disable eol-last */
/* eslint-disable padded-blocks */
/* eslint-disable max-len */
/* eslint-disable object-curly-spacing */
import * as functions from "firebase-functions/v1";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { GoogleGenerativeAI } from "@google/generative-ai";

admin.initializeApp();
const db = admin.firestore();

// ============================================================================
// 1. AI GATEWAY: Cognitive Behavioral Therapy Pipeline
// ============================================================================
export const generateCBTReframe = functions
  .runWith({ secrets: ["GEMINI_API_KEY"] })
  .https.onCall(async (data, context) => {
    // Authentication Security
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "User must be signed in.");
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError("internal", "Server configuration error.");
    }

    // Instantiating here prevents the 10000ms global boot timeout crash
    const genAI = new GoogleGenerativeAI(apiKey);
    const userText = data.userText;
    const modelName = data.model || "gemini-3.5-flash-lite";

    if (!userText || typeof userText !== "string") {
      throw new functions.https.HttpsError("invalid-argument", "No valid user text provided.");
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
      
      const cleanJson = text.replace(/```json/gi, "").replace(/```/g, "").trim();
      return JSON.parse(cleanJson);
      // eslint-disable-next-line no-trailing-spaces
      
    } catch (error) {
      console.error("Gemini API Error:", error);
      throw new functions.https.HttpsError("internal", "Failed to generate CBT reframe.");
    }
  });

// ============================================================================
// 2. SOMATIC GATEWAY: Grounding Rhythm Generator
// ============================================================================
export const generateSomaticRhythm = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be signed in.");
  }
  return { rhythm_pattern: [4, 7, 8], duration: 60 };
});

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

      const { type: eventType, app_user_id: appUserId, product_id: productId } = event;
      const userRef = db.collection("users").doc(appUserId);

      if (eventType === "INITIAL_PURCHASE" || eventType === "RENEWAL") {
        if (productId.includes("premium") || productId.includes("annual")) {
          await userRef.set({
            isPremium: true,
            premiumUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }
      } else if (eventType === "CANCELLATION" || eventType === "EXPIRATION") {
        await userRef.set({
          isPremium: false,
          premiumUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      } else if (eventType === "NON_RENEWING_PURCHASE") {
        let creditsToAdd = 0;
        if (productId === "sachet_cbt_10") creditsToAdd = 10;
        else if (productId === "sachet_cbt_25") creditsToAdd = 25;

        if (creditsToAdd > 0) {
          await userRef.set({
            walletBalance: admin.firestore.FieldValue.increment(creditsToAdd),
            lastTopUpAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }
      }

      res.status(200).send("Webhook processed successfully.");
    } catch (error) {
      console.error("Webhook Error:", error);
      res.status(500).send("Internal Server Error");
    }
  }
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
      reportsSnapshot.forEach((doc) => uniqueReporters.add(doc.data().reporterId));

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
  }
);