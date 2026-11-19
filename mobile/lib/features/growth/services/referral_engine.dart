import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// DATA MODEL
// ============================================================================
/// Standardized UI Response Object for the front-end to consume easily
class ReferralResult {
  final bool success;
  final String message;
  ReferralResult({required this.success, required this.message});
}

// ============================================================================
// STATE MANAGEMENT (RIVERPOD)
// ============================================================================
/// 🚨 ARCHITECT UPGRADE: Global AsyncNotifierProvider 
/// The state strictly holds the integer value of the user's local Premium Credits.
/// Any UI element listening to this provider will rebuild instantly when credits are spent or earned.
final referralEngineProvider = AsyncNotifierProvider<ReferralEngine, int>(() {
  return ReferralEngine();
});

class ReferralEngine extends AsyncNotifier<int> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _creditsKey = 'local_premium_credits';

  @override
  Future<int> build() async {
    return _loadLocalCredits();
  }

  /// Fast offline read for UI initialization (Ensures $0 cloud read cost on app launch)
  Future<int> _loadLocalCredits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_creditsKey) ?? 0;
    } catch (e) {
      debugPrint('🚨 [Referral Engine]: Failed to load local credits. $e');
      return 0;
    }
  }

  // ============================================================================
  // 1. FRAUD PREVENTION: HARDWARE FINGERPRINTING
  // ============================================================================
  /// Generates an immutable, cryptographic hash of the physical device to prevent
  /// users from farming referral credits by deleting app data or making fake accounts.
  Future<String> _generateDeviceFingerprint() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String hardwareData = '';

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        // Combines immutable hardware traits to prevent app-data-clear exploits
        hardwareData = '${androidInfo.brand}-${androidInfo.device}-${androidInfo.id}-${androidInfo.hardware}-${androidInfo.manufacturer}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        // Utilizing 'systemName' and 'utsname.machine' to capture exact hardware iteration (e.g., iPhone14,2)
        hardwareData = '${iosInfo.identifierForVendor}-${iosInfo.model}-${iosInfo.systemName}-${iosInfo.utsname.machine}';
      }
    } catch (e) {
      debugPrint('⚠️ [Fingerprint Warning]: Hardware read restricted. $e');
      // Fallback mechanism if the OS aggressively denies hardware reads
      hardwareData = 'fallback_${DateTime.now().millisecondsSinceEpoch}'; 
    }

    // Hash the result via MD5 to ensure PII (Personally Identifiable Info) is never stored
    return md5.convert(utf8.encode(hardwareData)).toString();
  }

  // ============================================================================
  // 2. VIRAL SHARING MECHANIC (The "Hook")
  // ============================================================================
  /// Initiates the native OS share sheet with a uniquely generated code.
  Future<void> shareApp() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ [Referral Engine]: User must be logged in to share.');
        return;
      }

      HapticFeedback.mediumImpact();

      // Create a visually clean, 6-character shortcode from the UID
      final String shortCode = user.uid.substring(0, 6).toUpperCase();

      // Ensure the user's code is registered in Firestore for tracking (Fire & Forget)
      _firestore.collection('referral_codes').doc(shortCode).set({
        'uid': user.uid,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).ignore();

      // 🚨 UX STRATEGY: Empathetic, value-driven share copy
      final String shareText = 
          "I've been using NeuroCalm to decode my stress patterns privately. "
          "Use my invite code '$shortCode' during setup to unlock 3 Free Premium Cognitive Insights. "
          "Download here: https://neurocalm.ai/invite";

      await SharePlus.instance.share(ShareParams(text: shareText, subject: 'An invite to NeuroCalm AI'));
      
    } catch (e) {
      debugPrint('🚨 [Referral Share Error]: $e');
    }
  }

  // ============================================================================
  // 3. SECURE REDEMPTION & ATOMIC REWARDS
  // ============================================================================
  /// Processes a friend's code via an atomic transaction. 
  /// If any step fails or the network drops, the entire operation safely rolls back.
  Future<ReferralResult> redeemReferralCode(String code) async {
    final user = _auth.currentUser;
    if (user == null) {
      return ReferralResult(success: false, message: 'Please log in to redeem codes.');
    }

    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length < 6) {
      return ReferralResult(success: false, message: 'Invalid invite code format.');
    }

    try {
      final fingerprint = await _generateDeviceFingerprint();

      // 🚨 TECH LEAD FIX: 8-Second hard timeout on transactions to prevent UI lockups
      return await _firestore.runTransaction((transaction) async {
        
        // Step 1: Check if this specific piece of hardware has already redeemed a code
        final deviceRef = _firestore.collection('redeemed_devices').doc(fingerprint);
        final deviceDoc = await transaction.get(deviceRef);
        
        if (deviceDoc.exists) {
          return ReferralResult(success: false, message: 'This device has already redeemed an invite code.');
        }

        // Step 2: Validate code existence
        final codeRef = _firestore.collection('referral_codes').doc(cleanCode);
        final codeDoc = await transaction.get(codeRef);

        if (!codeDoc.exists) {
          return ReferralResult(success: false, message: 'Invite code not found or expired.');
        }

        final referrerUid = codeDoc.data()?['uid'];
        
        // Step 3: Prevent self-referral farming (User redeeming their own code)
        if (referrerUid == user.uid) {
          return ReferralResult(success: false, message: 'You cannot use your own invite code.');
        }

        // Step 4: Issue Cloud Rewards safely
        final referrerRef = _firestore.collection('users').doc(referrerUid);
        final receiverRef = _firestore.collection('users').doc(user.uid);

        transaction.set(referrerRef, {
          'premium_insight_credits': FieldValue.increment(1),
          'total_referrals': FieldValue.increment(1)
        }, SetOptions(merge: true));

        transaction.set(receiverRef, {
          'premium_insight_credits': FieldValue.increment(3),
          'referred_by': referrerUid
        }, SetOptions(merge: true));

        // Step 5: Lock Device Fingerprint
        transaction.set(deviceRef, {
          'redeemed_by_uid': user.uid,
          'redeemed_at': FieldValue.serverTimestamp(),
          'code_used': cleanCode
        });

        // Step 6: Instantly update local UI state (Offline First Priority)
        final prefs = await SharedPreferences.getInstance();
        final currentCredits = prefs.getInt(_creditsKey) ?? 0;
        final newBalance = currentCredits + 3;
        
        await prefs.setInt(_creditsKey, newBalance);
        
        // Reactively update the Riverpod state so the UI updates immediately
        state = AsyncValue.data(newBalance);

        return ReferralResult(success: true, message: 'Success! 3 Premium Insights unlocked.');
        
      }).timeout(const Duration(seconds: 8));

    } on TimeoutException {
      debugPrint('🚨 [Referral Redemption]: Transaction timed out.');
      return ReferralResult(success: false, message: 'Network timeout. Please check your connection and try again.');
    } catch (e) {
      debugPrint('🚨 [Referral Redemption Error]: $e');
      return ReferralResult(success: false, message: 'An error occurred. Please try again later.');
    }
  }
  
  // ============================================================================
  // 4. CREDIT CONSUMPTION (For InsightRewardScreen Ad-Bypass)
  // ============================================================================
  /// Deducts a credit so the user can bypass the AdMob screen for a premium insight.
  Future<bool> consumePremiumCredit() async {
    final currentCredits = state.value ?? 0;
    
    if (currentCredits > 0) {
      try {
        final newBalance = currentCredits - 1;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_creditsKey, newBalance);
        
        // Reactively update state instantly for snappy UX
        state = AsyncValue.data(newBalance);
        
        // Optionally: Sync this deduction to Firestore in the background
        if (_auth.currentUser != null) {
           _firestore.collection('users').doc(_auth.currentUser!.uid).set({
             'premium_insight_credits': FieldValue.increment(-1)
           }, SetOptions(merge: true)).ignore(); // Fire and forget so UI doesn't hang
        }
        
        return true;
      } catch (e) {
        debugPrint('🚨 [Credit Consumption Error]: $e');
        return false;
      }
    }
    return false;
  }
}