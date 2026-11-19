import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/wallet_service.dart';

/// Give-get referrals, server-validated.
///
/// Flow: sharer gets a Play Store link carrying their code in the install
/// referrer -> friend installs -> app auto-redeems on first launch (no typing)
/// -> friend gets credits immediately -> sharer gets credits only after the
/// friend completes a first AI session (stops fake-install farming).
class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  static const _kAutoRedeemDone = 'referral_auto_redeem_done_v1';
  static const _packageId = 'com.kartikeyamishra.mobile';

  String? _cachedCode;
  int receiverCredits = 5;
  int referrerCredits = 5;

  Future<String?> getMyCode() async {
    if (_cachedCode != null) return _cachedCode;
    if (FirebaseAuth.instance.currentUser == null) return null;
    try {
      final res = await _functions.httpsCallable('getReferralCode').call<dynamic>();
      final data = Map<String, dynamic>.from(res.data as Map);
      _cachedCode = data['code'] as String?;
      if (data['receiverCredits'] is num) receiverCredits = (data['receiverCredits'] as num).toInt();
      if (data['referrerCredits'] is num) referrerCredits = (data['referrerCredits'] as num).toInt();
      return _cachedCode;
    } catch (e) {
      debugPrint('⚠️ [Referral]: code fetch failed: $e');
      return null;
    }
  }

  String inviteLink(String code) {
    final referrer = Uri.encodeComponent('utm_source=referral&utm_medium=invite&utm_content=$code');
    return 'https://play.google.com/store/apps/details?id=$_packageId&referrer=$referrer';
  }

  /// Opens the share sheet. Returns false if offline / not signed in.
  Future<bool> shareInvite() async {
    final code = await getMyCode();
    if (code == null) return false;
    final text = 'I use NeuroCalm to untangle anxious thoughts in about a minute — '
        'private, and it works in Hindi too. Get $receiverCredits free credits with my code $code:\n'
        '${inviteLink(code)}';
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Try NeuroCalm'));
    return true;
  }

  /// Manual redemption (Settings > "Have an invite code?").
  Future<String> redeem(String code) async {
    try {
      final res = await _functions.httpsCallable('redeemReferral').call<dynamic>({'code': code.trim()});
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['ok'] == true) await WalletService().sync();
      return (data['message'] as String?) ?? (data['ok'] == true ? 'Invite applied!' : 'Could not apply code.');
    } catch (e) {
      debugPrint('⚠️ [Referral]: redeem failed: $e');
      return 'Could not reach the server. Please try again.';
    }
  }

  /// Reads the Play install referrer once and redeems automatically.
  Future<void> autoRedeemFromInstallReferrer() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAutoRedeemDone) == true) return;
      if (FirebaseAuth.instance.currentUser == null) return; // retry next launch

      final details = await PlayInstallReferrer.installReferrer;
      final raw = Uri.decodeComponent(details.installReferrer ?? '');
      final params = Uri.splitQueryString(raw);
      final code = params['utm_content'];
      if (params['utm_source'] == 'referral' && code != null && code.length >= 6) {
        final message = await redeem(code);
        debugPrint('🎁 [Referral]: auto-redeem -> $message');
      }
      await prefs.setBool(_kAutoRedeemDone, true);
    } catch (e) {
      debugPrint('⚠️ [Referral]: install referrer unavailable: $e');
    }
  }
}
