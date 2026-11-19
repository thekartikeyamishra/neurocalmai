# Files to update (v1.2.0, build 9)

**Easiest and safest:** replace your whole local repo folder with the zip contents, then copy back your private files:
`mobile/.env` (public ad ids only), `mobile/android/key.properties`, your keystore (`.jks`), and `mobile/functions/.env` if you made one.

## New files (34)

- `AUDIT_AND_DEPLOY.md`
- `FILES_TO_UPDATE.md`
- `mobile/.env.example`
- `mobile/firestore.rules`
- `mobile/functions/.env.example`
- `mobile/functions/scripts/create-admin.mjs`
- `mobile/functions/src/admin.ts`
- `mobile/functions/src/ai.ts`
- `mobile/functions/src/common.ts`
- `mobile/functions/src/referrals.ts`
- `mobile/functions/src/wallet.ts`
- `mobile/hosting/admin/index.html`
- `mobile/hosting/app-ads.txt`
- `mobile/hosting/delete-account.html`
- `mobile/hosting/index.html`
- `mobile/hosting/privacy.html`
- `mobile/hosting/robots.txt`
- `mobile/hosting/terms.html`
- `mobile/ios/Runner/PrivacyInfo.xcprivacy`
- `mobile/lib/core/ads/ad_config.dart`
- `mobile/lib/core/ads/ad_consent_service.dart`
- `mobile/lib/core/app_info.dart`
- `mobile/lib/core/bootstrap/post_value_bootstrap.dart`
- `mobile/lib/core/navigation/app_navigator.dart`
- `mobile/lib/core/release/force_update_gate.dart`
- `mobile/lib/core/safety/crisis_detector.dart`
- `mobile/lib/core/safety/crisis_support_sheet.dart`
- `mobile/lib/features/growth/services/referral_service.dart`
- `mobile/lib/features/growth/widgets/invite_friends_card.dart`
- `mobile/lib/features/monetization/widgets/out_of_reflections_sheet.dart`
- `mobile/lib/features/onboarding/presentation/first_win_screen.dart`
- `mobile/lib/features/retention/services/reengagement_service.dart`
- `mobile/lib/features/retention/widgets/retention_cards.dart`
- `mobile/tool/repair_flutter_env.ps1`

## Changed files (50) — replace the whole file

- `.github/workflows/production_build.yml`
- `mobile/.gitignore`
- `mobile/android/app/build.gradle.kts`
- `mobile/android/app/src/main/AndroidManifest.xml`
- `mobile/firebase.json`
- `mobile/functions/package-lock.json`
- `mobile/functions/src/index.ts`
- `mobile/ios/Runner.xcodeproj/project.pbxproj`
- `mobile/ios/Runner/Info.plist`
- `mobile/lib/core/services/admob_reward_service.dart`
- `mobile/lib/core/services/iap_service.dart`
- `mobile/lib/core/services/local_notification_service.dart`
- `mobile/lib/core/services/remote_config_service.dart`
- `mobile/lib/core/services/secure_ai_gateway.dart`
- `mobile/lib/core/services/wallet_service.dart`
- `mobile/lib/core/utils/monetization_circuit_breaker.dart`
- `mobile/lib/features/aura/screens/aura_screen.dart`
- `mobile/lib/features/auth/screens/auth_screen.dart`
- `mobile/lib/features/auth/screens/welcome_screen.dart`
- `mobile/lib/features/community/presentation/create_community_screen.dart`
- `mobile/lib/features/community/presentation/event_detail_screen.dart`
- `mobile/lib/features/dashboard/screens/dashboard_screen.dart`
- `mobile/lib/features/emotion/services/share_service.dart`
- `mobile/lib/features/growth/screens/offline_waitlist_screen.dart`
- `mobile/lib/features/growth/services/referral_engine.dart`
- `mobile/lib/features/journal/screens/cbt_wizard_screen.dart`
- `mobile/lib/features/journal/screens/guided_task_screen.dart`
- `mobile/lib/features/journal/screens/journal_timeline_screen.dart`
- `mobile/lib/features/journal/screens/sleep_dump_screen.dart`
- `mobile/lib/features/journal/screens/standard_journal_screen.dart`
- `mobile/lib/features/journal/services/journal_storage_service.dart`
- `mobile/lib/features/monetization/geo_router.dart`
- `mobile/lib/features/monetization/screens/insight_reward_screen.dart`
- `mobile/lib/features/monetization/screens/premium_paywall_screen.dart`
- `mobile/lib/features/monetization/services/admob_service.dart`
- `mobile/lib/features/monetization/services/subscription_service.dart`
- `mobile/lib/features/monetization/widgets/native_ad_card.dart`
- `mobile/lib/features/monetization/widgets/smart_banner_card.dart`
- `mobile/lib/features/monetization/widgets/sponsor_reward_card.dart`
- `mobile/lib/features/settings/screens/language_selection_screen.dart`
- `mobile/lib/features/settings/screens/user_profile_screen.dart`
- `mobile/lib/features/settings/widgets/sensory_settings_sheet.dart`
- `mobile/lib/features/subscription/services/revenuecat_service.dart`
- `mobile/lib/features/therapy/services/gemini_service.dart`
- `mobile/lib/features/therapy/services/openai_service.dart`
- `mobile/lib/features/tracking/screens/habit_calendar_screen.dart`
- `mobile/lib/features/wallet/presentation/wallet_topup_dialog.dart`
- `mobile/lib/main.dart`
- `mobile/pubspec.yaml`
- `mobile/test/widget_test.dart`

Then in `mobile/`: run `tool/repair_flutter_env.ps1` (or `flutter clean`, `flutter pub get`, `flutter analyze --no-fatal-infos`).
