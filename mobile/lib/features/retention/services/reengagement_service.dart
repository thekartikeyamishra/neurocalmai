import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/local_notification_service.dart';

/// Brings back people who drift away or quit halfway — at near-zero cost.
///
/// * Win-back: when the app goes to the background we schedule a short,
///   gentle on-device sequence (day 1, 3, 7, 14, 30). Opening the app cancels
///   it, so active users never get nagged and no server or push cost is paid.
/// * Welcome-back: remembers how long the user was away so the dashboard can
///   greet returning users with a one-tap 60-second reflection.
/// * Resume: remembers a flow that was started but never saved (see
///   [markStarted] / [markFinished]) so the dashboard can offer to finish it.
class ReengagementService with WidgetsBindingObserver {
  ReengagementService._();
  static final ReengagementService instance = ReengagementService._();

  static const _kLastOpen = 'reengage_last_open_ms';
  static const _kFlow = 'reengage_open_flow';
  static const _kFlowAt = 'reengage_open_flow_ms';

  Future<void>? _startFuture;
  int _daysAway = 0;

  /// Days since the previous app open (computed once per process).
  int get daysAway => _daysAway;

  /// Idempotent; every caller can await it and gets the same result.
  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastOpen);
    final now = DateTime.now().millisecondsSinceEpoch;
    _daysAway = last == null ? 0 : ((now - last) / 86400000).floor();
    await prefs.setInt(_kLastOpen, now);
    WidgetsBinding.instance.addObserver(this);
    await LocalNotificationService().cancelWinBack();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      SharedPreferences.getInstance().then((p) => p.setInt(_kLastOpen, DateTime.now().millisecondsSinceEpoch));
      LocalNotificationService().scheduleWinBack();
    } else if (state == AppLifecycleState.resumed) {
      LocalNotificationService().cancelWinBack();
    }
  }

  /// Call when a user begins a multi-step flow (e.g. after tapping "analyse").
  Future<void> markStarted(String flowId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFlow, flowId);
    await prefs.setInt(_kFlowAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Call when that flow is saved/completed.
  Future<void> markFinished(String flowId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kFlow) == flowId) {
      await prefs.remove(_kFlow);
      await prefs.remove(_kFlowAt);
    }
  }

  /// The unfinished flow from the last 72 hours, if any.
  Future<String?> unfinishedFlow() async {
    final prefs = await SharedPreferences.getInstance();
    final flow = prefs.getString(_kFlow);
    final at = prefs.getInt(_kFlowAt) ?? 0;
    if (flow == null) return null;
    if (DateTime.now().millisecondsSinceEpoch - at > 72 * 3600 * 1000) {
      await prefs.remove(_kFlow);
      return null;
    }
    return flow;
  }

  Future<void> dismissUnfinished() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFlow);
    await prefs.remove(_kFlowAt);
  }
}
