import 'package:flutter/foundation.dart';

import '../services/local_notification_service.dart';
import '../../features/growth/services/referral_service.dart';
import '../../features/journal/services/journal_storage_service.dart';
import '../../features/notifications/services/push_notification_service.dart';

/// Work that should only happen after the user has felt value (first win),
/// e.g. notification permission prompts. Runs once per app process.
class PostValueBootstrap {
  PostValueBootstrap._();
  static bool _ran = false;

  static Future<void> run() async {
    if (_ran) return;
    _ran = true;
    await _guard('LocalNotifications', () => LocalNotificationService().init());
    await _guard('Push', () => PushNotificationService.instance.initialize());
    await _guard('Referral', ReferralService.instance.autoRedeemFromInstallReferrer);
    await _guard('JournalMigration', JournalStorageService.instance.migrateCloudJournalsToDevice);
  }

  static Future<void> _guard(String name, Future<void> Function() task) async {
    try {
      await task();
    } catch (e) {
      debugPrint('⚠️ [$name] (non-fatal): $e');
    }
  }
}
