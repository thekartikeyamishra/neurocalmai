import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// BACKGROUND HANDLER: Must be a top-level function
// ============================================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handles notifications when the app is completely terminated or in the background.
  // We keep this lightweight to respect the user's device battery and resources.
  debugPrint('🌙 [Push Service]: Handled background message: ${message.messageId}');
}

// ============================================================================
// CORE ENGINE: Ethical, Goal-Oriented Push Notifications
// ============================================================================
/// This service strictly governs outbound communications. It is designed to 
/// send only relevant, timely, and personalized notifications (e.g., Streak Savers) 
/// to help users achieve their goals, rather than interrupting them with spam.
class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._internal();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  PushNotificationService._internal();

  /// Initializes the Firebase Messaging engine, requests permissions ethically,
  /// and configures foreground/background listening streams.
  Future<void> initialize() async {
    try {
      // 1. Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Request explicit permission (Opt-in first)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ [Push Service]: User granted notification permissions.');
        await _configureTopics();
        _setupMessageHandlers();
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('✅ [Push Service]: User granted provisional permissions.');
        _setupMessageHandlers();
      } else {
        debugPrint('⚠️ [Push Service]: User declined notification permissions.');
      }
    } catch (e) {
      debugPrint('🚨 [Push Service Error]: Failed to initialize FCM - $e');
    }
  }

  /// Automatically subscribes the user to ethical, value-driven notification topics.
  Future<void> _configureTopics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

      if (notificationsEnabled) {
        // Subscribe to goal-oriented topics
        await _fcm.subscribeToTopic('streak_savers');
        await _fcm.subscribeToTopic('milestone_celebrations');
        debugPrint('✅ [Push Service]: Subscribed to value-driven topics.');
      } else {
        await _fcm.unsubscribeFromTopic('streak_savers');
        await _fcm.unsubscribeFromTopic('milestone_celebrations');
      }
    } catch (e) {
      debugPrint('⚠️ [Push Service Error]: Topic subscription failed - $e');
    }
  }

  /// Configures streams to listen for messages while the app is in the foreground.
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 [Push Service]: Foreground message received: ${message.notification?.title}');
      
      // If the app is open, we intercept the notification and rely on our 
      // internal Riverpod state (e.g., MilestoneNotifier) to show in-app 
      // micro-interactions (confetti/badges) instead of intrusive system popups.
      if (message.data['type'] == 'milestone') {
        // Example: Trigger local Riverpod provider to show celebration
        // ref.read(milestoneProvider.notifier).triggerCelebration(message.data['badge_name']);
      }
    });

    // Handle when a user taps a notification to open the app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🚪 [Push Service]: App opened via notification tap.');
      _routeMessage(message);
    });

    // Handle when the app is launched from a terminated state via a notification
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('🚀 [Push Service]: App launched from terminated state via push.');
        _routeMessage(message);
      }
    });
  }

  /// Routes the user to the correct screen based on the notification payload.
  void _routeMessage(RemoteMessage message) {
    final String? routeType = message.data['route'];
    
    if (routeType == null) return;

    // TODO: Integrate with Global Navigation Key to push routes
    // if (routeType == 'streak_saver') {
    //   navigatorKey.currentState?.pushNamed('/journal_intent');
    // } else if (routeType == 'premium_discovery') {
    //   navigatorKey.currentState?.pushNamed('/paywall');
    // }
  }

  /// Opts the user out of all non-critical notifications.
  Future<void> disableNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);
      
      await _fcm.unsubscribeFromTopic('streak_savers');
      await _fcm.unsubscribeFromTopic('milestone_celebrations');
      
      debugPrint('🛑 [Push Service]: All non-critical notifications disabled.');
    } catch (e) {
      debugPrint('⚠️ [Push Service Error]: Failed to disable notifications - $e');
    }
  }
}

/// Global Riverpod Provider for easy access across the settings UI
final pushNotificationProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService.instance;
});