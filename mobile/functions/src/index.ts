/* eslint-disable eol-last */
/**
 * ============================================================================
 * NEUROCALM AI - FIREBASE CLOUD FUNCTIONS ENTRY POINT
 * ============================================================================
 */

import * as admin from "firebase-admin";

// 1. Globally initialize the Firebase Admin SDK.
if (!admin.apps.length) {
  admin.initializeApp();
}

// ============================================================================
// EXPORTED MODULES
// ============================================================================

// User-Generated Content (UGC) Moderation & Safety
export * from "./moderation";

// Secure LLM Processing for Voice Therapy
export * from "./ai_gateway";

// RevenueCat Webhooks for Subscriptions & UPI Wallet Top-ups
export * from "./subscriptions";

