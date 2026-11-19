# NeuroCalm AI — v1.2.0 (build 9) audit fixes & deploy runbook

## Why ad revenue was ~zero (root causes, all fixed)

| # | Root cause | Fix |
|---|-----------|-----|
| 1 | Release builds fell back to **Google test ad units** whenever a key was missing from `.env` (test ads pay $0). Banner fell back to an **empty id**. | `lib/core/ads/ad_config.dart`: `--dart-define` → `.env` → compiled-in prod id → *disabled + logged*. Never test ids in release. |
| 2 | **No Google UMP consent** → limited/no ads in EEA/UK (highest eCPM). | `AdConsentService` runs before the SDK; "Privacy & ad choices" in Settings. |
| 3 | Ads hidden until a user had **rated 3 insights** (`total_investments`) — most users never do. | Grace = first app session only (Remote Config `ad_grace_period_sessions`). |
| 4 | Geo router was a **hard-coded mock (`'IN'`)**; non-IN users were routed to "subscription" and saw **no native ads**. | Every non-premium user is ad-supported in every region. |
| 5 | **300 starter credits** at 1 credit/use + sponsor card only when balance < 50 → rewarded ads were practically never offered. | Server economy: 5 free AI reflections/day, then credits; 1 rewarded ad = 2 credits (all tunable). Out-of-reflections sheet offers the ad at the moment of intent. |
| 6 | Rewarded flow had a **4-second timeout that fired while the ad was playing** and discarded the reward users had just watched. | Removed; only SDK callbacks decide. |
| 7 | Banner widget **not placed anywhere**; native only on one screen; interstitial fired on the **paywall exit** (hurts conversion). | Banner on dashboard/timeline/calendar, native on dashboard + library, interstitial only after completed sessions (cooldown + daily cap), app-open ad for returning users. Never on breathing/panic/voice/crisis UI. |
| 8 | Rewarded load gave up after 3 failures until restart. | Exponential backoff, never permanently stops. |

## Security / money / privacy fixes
- **Gemini + OpenAI API keys shipped inside the APK** (`.env` is a bundled asset). All AI now goes through Cloud Functions (`aiTherapyReply`, `generateCBTReframe`). **Rotate both keys** (see runbook).
- Wallet was **client-writable** (free unlimited credits) and purchased sachets were credited to `users/{uid}.walletBalance` while the app read `wallets/{uid}.balance` → **paid credits never arrived**. Wallet is now server-authoritative; webhook credits the right doc; Firestore rules block client writes.
- Rewarded ads verified server-side (capped, idempotent, AdMob SSV endpoint `admobSsv`).
- Server owns model choice (clients could previously request any model), input caps, burst + daily abuse caps, refunds on failure, crisis pre-check.
- RevenueCat webhook: idempotent, constant-time secret check, `CANCELLATION` no longer revokes access early, lifetime + transfer handled.
- Entitlement id mismatch (`"premium"` vs `"NeuroCalm AI Pro"`) meant some purchase paths **never unlocked premium**. Fixed + fallback to any active entitlement.
- A second, independent Play Billing client (`in_app_purchase`) ran beside RevenueCat with an always-`true` receipt check; now a mirror of RevenueCat.
- Premium paywall had **no purchase path**; now lists localized plans, purchases, restores.
- Structured journal screens **never saved** (TODOs) — entries now saved on-device; legacy cloud journals migrated to device and deleted from cloud.
- Daily reminder fired at **8 PM UTC (1:30 AM IST)** — fixed to device time.
- App start blocked up to **60 s** on Remote Config when offline — now instant.
- Crisis safety: on-device + server detection → helpline sheet (Tele-MANAS 14416, 988, Samaritans, 112).
- Guest sign-out warning, account + cloud-data deletion (`deleteMyData`), restore purchases, support entry, force-update gate.
- CI pointed at a non-existent `./backend` and Flutter 3.19 (can't build Dart ^3.11). Fixed. Gradle no longer fails without `key.properties`.

## Deploy runbook (in this order)

1. **Secrets** (one time):
   `firebase functions:secrets:set GEMINI_API_KEY` (use a NEW key) and confirm `RC_WEBHOOK_SECRET` exists.
2. **Functions config**: `cp mobile/functions/.env.example mobile/functions/.env` and adjust.
3. **Deploy backend first** (old app versions keep working — names/regions unchanged):
   `cd mobile && firebase deploy --only functions,firestore:rules,hosting`
   - Firebase console → Authentication → Sign-in method: enable **Email/Password** (for the admin) and keep **Anonymous** on.
   - Create the admin (credentials only as environment variables, never in code): see `mobile/functions/scripts/create-admin.mjs`.
   - Admin console: `https://neurocalmnow.web.app/admin/` (noindex; only accounts with the `admin` claim get data).
   - Public pages the stores require (same deploy): `/privacy`, `/terms`, `/delete-account`, `/app-ads.txt`. Set `https://neurocalmnow.web.app` as the **developer website** in Play Console (and App Store Connect marketing URL) so AdMob finds app-ads.txt.
   - Auto-delete bookkeeping docs (keeps Firestore small and cheap):
     `gcloud firestore fields ttls update expireAt --collection-group=adClaims --enable-ttl --project=neurocalmnow`
     (repeat for `ssv` and `rcEvents`).
4. **AdMob console**: create Banner, Native, Interstitial and App-open units for the app; on the rewarded unit enable **SSV** with URL
   `https://us-central1-neurocalmnow.cloudfunctions.net/admobSsv`. Publish **app-ads.txt** on the developer website listed in Play Console:
   `google.com, pub-4557897331416844, DIRECT, f08c47fec0942fa0` (already in `mobile/hosting/app-ads.txt`).
   Create the **GDPR + US-states messages** in AdMob → Privacy & messaging.
5. **Remote Config**: set `rewarded_ad_credit_payout=2` (old console value 50 is wrong), `support_email`, `privacy_policy_url`.
6. **Build**:
   ```
   flutter pub get
   flutter build appbundle --release \
     --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-4557897331416844/XXXX \
     --dart-define=ADMOB_NATIVE_ANDROID=ca-app-pub-4557897331416844/XXXX \
     --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-4557897331416844/XXXX \
     --dart-define=ADMOB_APP_OPEN_ANDROID=ca-app-pub-4557897331416844/XXXX
   ```
   Remove `GEMINI_API_KEY` / `OPENAI_API_KEY` from `mobile/.env` before building.
7. **Play Console**: update Data safety (AI text/voice processed by Google, not stored; ads + Advertising ID; account deletion available in-app), staged rollout 10% → 50% → 100% while watching Android vitals + AdMob.
8. **After ~80% of users are on build 9**: set Remote Config `min_supported_build=9`, **revoke the old Gemini and OpenAI keys**, set `REQUIRE_ADMOB_SSV=true` once SSV callbacks show up, and change `journals` create/update rules to `false`.

## v1.2.0 additions
- **Company admin console** (`mobile/admin/index.html`, Firebase Hosting): daily AI calls, estimated AI cost, error rate, free/credit/premium mix, rewarded ads, new users, purchases + subscription revenue, referrals, crisis sheets; user lookup and audited goodwill-credit grants for support. Admin = Firebase custom claim set by `scripts/create-admin.mjs` from env vars; rotate by re-running it.
- **Win-back system**: on-device notifications on day 1/3/7/14/30 after the app is left (cancelled on return), "Finish your reflection?" resume card for flows abandoned halfway, "Welcome back" one-tap reflection after 3+ days away.
- **Weekly Pattern Report** card: on-device, zero AI cost, share-safe.
- **Cheaper AI metering**: 2 Firestore reads per free AI call instead of 3; TTL on bookkeeping collections.

## Store acceptance (Google Play + Apple App Store)
Done in code: in-app account deletion + web deletion page, privacy policy + terms pages, subscription auto-renew disclosure with Terms/Privacy links on the paywall, restore purchases, honest permission texts, UMP consent (+ ATT text on iOS), crisis hand-off, "self-help, not medical" positioning, no hidden placeholder URL schemes, unused iOS background mode removed, iOS 15 minimum (Firebase 12), privacy manifest (`ios/Runner/PrivacyInfo.xcprivacy` — add it to the Runner target in Xcode once), speech-recognition package visibility on Android.

iOS build extras: `--dart-define=REVENUECAT_IOS_KEY=appl_...` and the `ADMOB_*_IOS` ad unit ids; enable HealthKit capability only if you keep the health import feature on iOS; create the IDFA explainer message in AdMob → Privacy & messaging (it triggers Apple's tracking prompt).

## If VS Code shows "dispose isn't defined for TextEditingController" or "Undefined class ValueNotifier"
These appear in untouched files too, so the SDK/analyzer cache is out of sync. Run `mobile/tool/repair_flutter_env.ps1`, then restart the Dart analysis server.
The `package:flutter/material.dart is deprecated` notice on Flutter 3.47+ is a warning only; the import still compiles. Migrate to `material_ui` later, once your dependencies support it.

## Verified here
- Functions: `tsc` strict build + ESLint clean; unit tests for crisis detection, JSON parsing, model fallback (404 → 400-without-thinking → success, 429 → `busy`), and AdMob SSV signature verification (valid / tampered / unknown key / ping).
- Flutter code could **not** be compiled in this environment (no Flutter SDK / pub.dev access). APIs were checked against the exact plugin sources (google_mobile_ads 9.0.0, purchases_flutter, share_plus 12). Run `flutter analyze` and `flutter test` before release; fix anything they flag.
