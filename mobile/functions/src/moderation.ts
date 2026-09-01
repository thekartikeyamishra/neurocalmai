/* eslint-disable object-curly-spacing */
import {
  onDocumentCreated,
  FirestoreEvent,
} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { QueryDocumentSnapshot } from "firebase-admin/firestore";

// Initialize the Firebase Admin SDK to bypass client security rules
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// The number of unique user reports required to automatically hide
// content. Google Play recommends a low threshold to ensure rapid
// response to safety violations.
const SUSPENSION_THRESHOLD = 3;

/**
 * Triggered automatically every time a user submits a new report via
 * the app. Counts unique reports against the content. If the
 * threshold is met, it immediately changes the status to 'suspended'
 * to hide it from the public feed.
 */
export const processUGCReport = onDocumentCreated(
  "reports/{reportId}",
  async (
    event: FirestoreEvent<
      QueryDocumentSnapshot | undefined,
      { reportId: string }
    >
  ) => {
    const snap = event.data;

    // Failsafe: Ensure data exists
    if (!snap) {
      console.warn("No data associated with the event.");
      return;
    }

    const reportData = snap.data();
    const contentId = reportData.contentId as string | undefined;
    const contentType = reportData.contentType as string | undefined;
    const reporterId = reportData.reporterId as string | undefined;

    // Failsafe: Ensure valid data structure
    if (!contentId || !contentType || !reporterId) {
      console.warn(
        `Invalid report data for reportId: ${event.params.reportId}`
      );
      return;
    }

    try {
      // 1. Fetch all reports for this specific piece of content
      const reportsSnapshot = await db
        .collection("reports")
        .where("contentId", "==", contentId)
        .get();

      // 2. Count UNIQUE reporters (prevents one malicious user from
      // spam-reporting to trigger a ban)
      const uniqueReporters = new Set<string>();
      reportsSnapshot.forEach((doc) => {
        uniqueReporters.add(doc.data().reporterId);
      });

      console.log(
        `Content ${contentId} has ${uniqueReporters.size} unique reports.`
      );

      // 3. If threshold is met, suspend the content
      if (uniqueReporters.size >= SUSPENSION_THRESHOLD) {
        if (contentType === "community") {
          // Suspend a specific chapter/community
          await db.collection("communities").doc(contentId).update({
            status: "suspended",
            suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`🔒 Community ${contentId} automatically suspended.`);
        } else if (contentType === "event") {
          // Because events are in a nested collection
          // (communities/{id}/events/{eventId}), we use a
          // collectionGroup query to find and suspend it safely.
          const eventsSnap = await db
            .collectionGroup("events")
            .where(
              admin.firestore.FieldPath.documentId(),
              "==",
              contentId
            )
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
            console.log(`🔒 Event ${contentId} automatically suspended.`);
          }
        } else if (contentType === "user") {
          // Flag user for manual moderation review
          await db.collection("users").doc(contentId).update({
            status: "under_review",
            flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`⚠️ User ${contentId} flagged for review.`);
        }
      }
    } catch (error) {
      console.error("🚨 Error processing moderation report: ", error);
    }
  }
);
