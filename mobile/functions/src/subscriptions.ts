/* eslint-disable linebreak-style */
/* eslint-disable eol-last */
/* eslint-disable linebreak-style */
/* eslint-disable padded-blocks */
/* eslint-disable linebreak-style */
/* eslint-disable brace-style */
/* eslint-disable linebreak-style */
/* eslint-disable no-trailing-spaces */
/* eslint-disable max-len */
/* eslint-disable linebreak-style */
import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const db = admin.firestore();

// We expect the Webhook Auth Token to be stored in Firebase Secret Manager.
// This prevents random people on the internet from spoofing payment events.
const REVENUECAT_WEBHOOK_SECRET = process.env.RC_WEBHOOK_SECRET || "";

/**
 * Listens for server-to-server webhook events from RevenueCat.
 * Handles Subscription renewals, cancellations, and one-time Sachet top-ups.
 */
export const revenueCatWebhook = onRequest(
  {
    secrets: ["RC_WEBHOOK_SECRET"],
    maxInstances: 10,
  },
  async (req, res) => {
    try {
      // 1. Security Check: Validate the Authorization header
      const authHeader = req.headers.authorization;
      if (authHeader !== `Bearer ${REVENUECAT_WEBHOOK_SECRET}`) {
        console.warn("🚨 Unauthorized webhook attempt.");
        res.status(401).send("Unauthorized");
        return;
      }

      // 2. Extract Event Data
      const event = req.body?.event;
      if (!event) {
        res.status(400).send("No event data provided.");
        return;
      }

      const eventType = event.type; // e.g., INITIAL_PURCHASE, RENEWAL, NON_RENEWING_PURCHASE
      const appUserId = event.app_user_id; // This matches the Firebase UID
      const productId = event.product_id;

      if (!appUserId) {
        res.status(400).send("No app_user_id provided.");
        return;
      }

      console.log(`💰 Processing ${eventType} for user ${appUserId}, product: ${productId}`);

      const userRef = db.collection("users").doc(appUserId);

      // 3. Handle Subscription Events (Tier 1 International)
      if (
        eventType === "INITIAL_PURCHASE" ||
        eventType === "RENEWAL"
      ) {
        // If it's a recurring subscription, grant premium access
        if (productId.includes("premium") || productId.includes("annual")) {
          await userRef.set(
            {
              isPremium: true,
              premiumUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true}
          );
          console.log(`✅ User ${appUserId} premium status ACTIVATED.`);
        }
      } 
      else if (
        eventType === "CANCELLATION" ||
        eventType === "EXPIRATION"
      ) {
        await userRef.set(
          {
            isPremium: false,
            premiumUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true}
        );
        console.log(`❌ User ${appUserId} premium status REVOKED.`);
      }

      // 4. Handle One-Time Consumables (UPI Sachets for India)
      else if (eventType === "NON_RENEWING_PURCHASE") {
        let creditsToAdd = 0;

        // Map product IDs to credit amounts (Ensure these match MonetizationConstants in Flutter)
        if (productId === "sachet_cbt_10") creditsToAdd = 10;
        else if (productId === "sachet_cbt_25") creditsToAdd = 25;

        if (creditsToAdd > 0) {
          // Use FieldValue.increment to prevent race conditions if the user buys multiple packs quickly
          await userRef.set(
            {
              walletBalance: admin.firestore.FieldValue.increment(creditsToAdd),
              lastTopUpAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true}
          );
          console.log(`🪙 Added ${creditsToAdd} credits to user ${appUserId}'s wallet.`);
        }
      }

      // 5. Always return 200 OK so RevenueCat knows we received it successfully
      res.status(200).send("Webhook processed successfully.");
      
    } catch (error) {
      console.error("🚨 Error processing RevenueCat webhook:", error);
      // Return 500 so RevenueCat will retry the webhook later
      res.status(500).send("Internal Server Error");
    }
  }
);