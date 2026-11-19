/// Build metadata used by the force-update gate (keep in sync with pubspec
/// `version: x.y.z+BUILD`). Avoids adding package_info_plus just for this.
class AppInfo {
  AppInfo._();
  static const String versionName = '1.2.0';
  static const int buildNumber = 9;
}
