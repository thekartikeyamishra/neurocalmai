// cSpell:disable
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// ZERO-COST TRIGGERS: Handles daily behavioral nudges completely offline.
/// Acts as the internal trigger for the Hooked model, pinging users at
/// high-conversion times without incurring Firebase Cloud Messaging (FCM) costs.
class LocalNotificationService {
  // Singleton instance
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initializes the notification plugin, configures timezones, and sets up routing.
  /// Call this in `main.dart` during app initialization.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      // Initialize native settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission:
                false, // We request manually to control the UX timing
            requestBadgePermission: false,
            requestSoundPermission: false,
          );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // 🚨 FIX: The correct named parameter for FlutterLocalNotificationsPlugin.initialize() is `settings:`
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle routing when the user taps the notification
          // e.g., triggering a navigator key to open the VoiceReframeScreen
          debugPrint('🔔 [Notification Tapped]: Payload - ${response.payload}');
        },
      );

      _isInitialized = true;

      // Request permissions and schedule the retention hook
      await _requestPermissions();
      await _scheduleDailyEveningTrigger();

      debugPrint('🔔 [LocalNotificationService]: Initialized and scheduled.');
    } catch (e) {
      debugPrint('🚨 [Local Notification Init Error]: $e');
    }
  }

  /// Requests OS-level permissions for iOS and Android 13+.
  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } else if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();

        // Android 13+ requires explicit opt-in for notifications
        await androidImplementation?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('🚨 [Notification Permission Error]: $e');
    }
  }

  /// The Hooked Model 'Internal Trigger': A gentle, non-annoying nudge at 8 PM local time.
  /// Costs $0.00 and executes entirely on-device without waking backend servers.
  Future<void> _scheduleDailyEveningTrigger() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'neurocalm_daily_reflection',
          'Daily Reflection',
          channelDescription: 'Gentle evening reminders to clear your mind.',
          importance: Importance
              .low, // Low importance prevents annoying pop-up sounds/vibrations
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false, // Keep it calm and silent to respect user peace
    );

    const NotificationDetails platformSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // FIX: `tz.local` is UTC unless explicitly set, so "8 PM" fired at
    // 8 PM UTC (1:30 AM in India). We compute 8 PM in the *device* zone and
    // schedule the equivalent UTC instant; the daily repeat keeps that time.
    final nowLocal = DateTime.now();
    var targetLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, 20, 0);
    if (!targetLocal.isAfter(nowLocal)) {
      targetLocal = targetLocal.add(const Duration(days: 1));
    }
    final scheduledDate = tz.TZDateTime.from(targetLocal.toUtc(), tz.UTC);

    // 🚨 FIX: Modern SDK v14+ requires fully named arguments for zonedSchedule
    await _notificationsPlugin.zonedSchedule(
      id: 0,
      title: 'Time to center yourself.',
      body: 'Take 60 seconds to vent to the AI and clear your mind before bed.',
      scheduledDate: scheduledDate,
      notificationDetails: platformSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexact, // Battery optimized
      matchDateTimeComponents:
          DateTimeComponents.time, // Repeats daily at this exact time
      payload: 'evening_reflection_trigger',
    );
  }

  // ---------------------------------------------------------------------------
  // WIN-BACK SEQUENCE (zero server cost, works offline, fully on-device)
  // Scheduled when the app goes to background, cancelled when it returns, so
  // only people who actually drift away ever receive them.
  // ---------------------------------------------------------------------------
  static const List<int> _winBackIds = [101, 102, 103, 104, 105];
  static const List<int> _winBackDays = [1, 3, 7, 14, 30];
  static const List<List<String>> _winBackCopy = [
    ['Your free reflections refreshed', 'One minute is enough to untangle today\'s loudest thought.'],
    ['Still replaying something?', 'Name the thinking trap in 60 seconds. It usually loosens its grip.'],
    ['A fresh start is one tap away', 'No streak pressure. Just one calm minute when you want it.'],
    ['Your journal is safe on this phone', 'Come back any time — your past reframes are waiting for you.'],
    ['We saved you a calm minute', 'If things feel heavy, a 60-second reflection can help. We\'re here.'],
  ];

  bool get isReady => _isInitialized;

  Future<void> scheduleWinBack() async {
    if (!_isInitialized) return; // never before the user granted value/permission
    try {
      await cancelWinBack();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'neurocalm_gentle_nudges',
          'Gentle check-ins',
          channelDescription: 'Occasional reminders when you have been away for a while.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(presentSound: false),
      );
      final now = DateTime.now();
      for (var i = 0; i < _winBackIds.length; i++) {
        final day = now.add(Duration(days: _winBackDays.elementAt(i)));
        final local = DateTime(day.year, day.month, day.day, 19, 30);
        final copy = _winBackCopy.elementAt(i);
        await _notificationsPlugin.zonedSchedule(
          id: _winBackIds.elementAt(i),
          title: copy.first,
          body: copy.last,
          scheduledDate: tz.TZDateTime.from(local.toUtc(), tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          payload: 'win_back_${_winBackDays.elementAt(i)}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [WinBack]: schedule failed: $e');
    }
  }

  Future<void> cancelWinBack() async {
    if (!_isInitialized) return;
    for (final id in _winBackIds) {
      try {
        await _notificationsPlugin.cancel(id: id);
      } catch (e) {
        debugPrint('⚠️ [WinBack]: cancel $id failed: $e');
      }
    }
  }

  /// Cancels all scheduled local notifications.
  /// Useful if the user explicitly disables reminders in their profile settings.
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('🔔 [LocalNotificationService]: All notifications cancelled.');
    } catch (e) {
      debugPrint('🚨 [Cancel Notifications Error]: $e');
    }
  }
}
// cSpell:enable