// Creates or updates the company admin account and grants the `admin` claim.
// Credentials come ONLY from environment variables — nothing is hard-coded,
// so you can rotate them any time by re-running this script.
//
// PowerShell (Windows):
//   cd mobile\functions
//   gcloud auth application-default login      # or set GOOGLE_APPLICATION_CREDENTIALS
//   $env:GCLOUD_PROJECT="neurocalmnow"
//   $env:ADMIN_USERNAME="your-username"
//   $env:ADMIN_EMAIL="you@example.com"
//   $env:ADMIN_PASSWORD="a-new-strong-password"
//   node scripts/create-admin.mjs
//   Remove-Item Env:ADMIN_PASSWORD
//
// To revoke: ADMIN_EMAIL=... node scripts/create-admin.mjs --revoke
import admin from "firebase-admin";

const {ADMIN_USERNAME, ADMIN_EMAIL, ADMIN_PASSWORD} = process.env;
const revoke = process.argv.includes("--revoke");

if (!ADMIN_EMAIL || (!revoke && (!ADMIN_PASSWORD || !ADMIN_USERNAME))) {
  console.error("Set ADMIN_USERNAME, ADMIN_EMAIL and ADMIN_PASSWORD environment variables first.");
  process.exit(1);
}
if (!revoke && ADMIN_PASSWORD.length < 12) {
  console.error("Use a password of at least 12 characters.");
  process.exit(1);
}

admin.initializeApp({projectId: process.env.GCLOUD_PROJECT || "neurocalmnow"});
const auth = admin.auth();

let user;
try {
  user = await auth.getUserByEmail(ADMIN_EMAIL);
} catch {
  user = null;
}

if (revoke) {
  if (user) await auth.setCustomUserClaims(user.uid, {});
  if (user) await auth.revokeRefreshTokens(user.uid);
  console.log(`Admin access revoked for ${ADMIN_EMAIL}.`);
  process.exit(0);
}

if (user) {
  user = await auth.updateUser(user.uid, {password: ADMIN_PASSWORD, displayName: ADMIN_USERNAME, emailVerified: true});
} else {
  user = await auth.createUser({email: ADMIN_EMAIL, password: ADMIN_PASSWORD, displayName: ADMIN_USERNAME, emailVerified: true});
}
await auth.setCustomUserClaims(user.uid, {admin: true, username: ADMIN_USERNAME});
await auth.revokeRefreshTokens(user.uid); // force fresh tokens with the claim
await admin.firestore().collection("admins").doc(user.uid).set(
  {username: ADMIN_USERNAME, email: ADMIN_EMAIL, updatedAt: admin.firestore.FieldValue.serverTimestamp()},
  {merge: true},
);
console.log(`Admin ready: ${ADMIN_USERNAME} <${ADMIN_EMAIL}> (uid ${user.uid}). Password was not stored anywhere by this script.`);
process.exit(0);
