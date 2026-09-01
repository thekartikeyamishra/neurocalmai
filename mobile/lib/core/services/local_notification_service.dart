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

      await _notificationsPlugin.initialize(
        initSettings,
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

    final now = tz.TZDateTime.now(tz.local);
    // Target 8:00 PM local time
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      20,
      0,
    );

    // If it's already past 8 PM today, push the schedule to tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      0, // Notification ID
      'Time to center yourself.',
      'Take 60 seconds to vent to the AI and clear your mind before bed.',
      scheduledDate,
      platformSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexact, // Battery optimized
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // Repeats daily at this exact time
      payload: 'evening_reflection_trigger',
    );
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
