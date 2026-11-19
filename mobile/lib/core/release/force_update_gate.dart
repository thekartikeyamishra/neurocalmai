import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../navigation/app_navigator.dart';
import '../services/remote_config_service.dart';

/// Lets you retire broken/insecure builds remotely: set Remote Config
/// `min_supported_build` (blocking) or `latest_build` (soft prompt).
class ForceUpdateGate {
  ForceUpdateGate._();
  static bool _shown = false;

  static Future<void> check() async {
    if (_shown) return;
    final rc = RemoteConfigService();
    final min = rc.minSupportedBuild;
    final latest = rc.latestBuild;
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    final mustUpdate = min > 0 && AppInfo.buildNumber < min;
    final canUpdate = latest > AppInfo.buildNumber;
    if (!mustUpdate && !canUpdate) return;
    _shown = true;
    await showDialog<void>(
      context: ctx,
      barrierDismissible: !mustUpdate,
      builder: (dCtx) => PopScope(
        canPop: !mustUpdate,
        child: AlertDialog(
          title: Text(mustUpdate ? 'Update required' : 'A calmer version is ready'),
          content: Text(mustUpdate
              ? 'This version is no longer supported. Please update to keep your tools working safely.'
              : 'Update for the latest fixes and improvements.'),
          actions: [
            if (!mustUpdate)
              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Later')),
            ElevatedButton(
              onPressed: () => launchUrl(Uri.parse(rc.playStoreUrl), mode: LaunchMode.externalApplication),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}
