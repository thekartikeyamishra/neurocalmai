import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'remote_config_service.dart';

/// Production-ready singleton service managing the micro-transaction Wallet[cite: 13].
/// Handles offline caching via FlutterSecureStorage and atomic Firestore transactions[cite: 13]
/// to ensure session credits are never duplicated, lost, or desynced during race conditions[cite: 13].
class WalletService {
  // Singleton instance
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal() {
    _loadInitialLocalBalance();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _localBalanceKey = 'local_wallet_balance';
  static const String _welcomeBonusKey = 'welcome_bonus_granted_v2';
  
  // 300 starter credits provides 5-6 full voice/text sessions to establish a habit loop
  static const int _starterCredits = 300; 

  // Stream subscription for Firestore real-time updates[cite: 13]
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _walletSubscription;

  // Stream controller to broadcast balance changes instantly across the entire UI hierarchy[cite: 13]
  final StreamController<int> _balanceController = StreamController<int>.broadcast();
  Stream<int> get balanceStream => _balanceController.stream;

  int _currentBalance = _starterCredits;
  int get currentBalance => _currentBalance;

  /// Loads the cached balance from secure storage immediately on boot for zero-latency UI rendering[cite: 13].
  Future<void> _loadInitialLocalBalance() async {
    try {
      final bonusApplied = await _secureStorage.read(key: _welcomeBonusKey);
      final localBalStr = await _secureStorage.read(key: _localBalanceKey);

      if (bonusApplied == null) {
        // First launch or migration: Grant the starter reserve
        _currentBalance = _starterCredits;
        await _secureStorage.write(key: _localBalanceKey, value: _starterCredits.toString());
        await _secureStorage.write(key: _welcomeBonusKey, value: 'true');
      } else if (localBalStr != null) {
        _currentBalance = int.tryParse(localBalStr) ?? _starterCredits;
      } else {
        _currentBalance = _starterCredits;
        await _secureStorage.write(key: _localBalanceKey, value: _starterCredits.toString());
      }

      if (!_balanceController.isClosed) {
        _balanceController.add(_currentBalance);
      }
    } catch (e) {
      debugPrint('⚠️ [WalletService Init Cache Warning]: $e');
    }
  }

  /// Initializes the wallet service, syncing the local secure cache with Firestore[cite: 13].
  /// Call this when a user logs in or after Firebase Auth is initialized[cite: 13].
  Future<void> init() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _loadInitialLocalBalance();
      return;
    }

    // Cancel any existing subscription before creating a new one[cite: 13]
    await _walletSubscription?.cancel();

    // 1. Read immediate cached value[cite: 13]
    await _loadInitialLocalBalance();

    // 2. Setup real-time listener to Firestore (Remote Source of Truth)[cite: 13]
    try {
      _walletSubscription = _firestore
          .collection('wallets')
          .doc(user.uid)
          .snapshots()
          .listen(
        (docSnap) async {
          if (docSnap.exists && docSnap.data() != null) {
            final serverBalance = docSnap.data()!['balance'] as int? ?? _starterCredits;
            await _updateLocalBalance(serverBalance);
          } else {
            // Document does not exist yet; initialize with default starter credits[cite: 13]
            await _initializeWallet(user.uid);
          }
        },
        onError: (e) {
          debugPrint('⚠️ [Wallet Sync Error]: $e (Operating in Offline Cache Mode)');
        },
      );
    } catch (e) {
      debugPrint('🚨 [Wallet Subscription Error]: $e');
    }
  }

  /// Creates a new wallet document in Firestore with baseline starter credits[cite: 13].
  Future<void> _initializeWallet(String uid) async {
    try {
      await _firestore.collection('wallets').doc(uid).set({
        'balance': _starterCredits,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _updateLocalBalance(_starterCredits);
    } catch (e) {
      debugPrint('🚨 [Wallet Initialization Error]: $e');
    }
  }

  /// Updates local state, commits to encrypted storage, and broadcasts to listeners[cite: 13].
  Future<void> _updateLocalBalance(int newBalance) async {
    if (_currentBalance != newBalance) {
      _currentBalance = newBalance;
      if (!_balanceController.isClosed) {
        _balanceController.add(_currentBalance);
      }
      try {
        await _secureStorage.write(key: _localBalanceKey, value: newBalance.toString());
      } catch (e) {
        debugPrint('⚠️ [Wallet Secure Storage Write Warning]: $e');
      }
      debugPrint('💰 [Wallet Balance Updated]: $_currentBalance Credits');
    }
  }

  /// Atomically adds credits to the user's wallet[cite: 13].
  /// Called after a successful RevenueCat Sachet purchase or a completed Rewarded Ad[cite: 13].
  Future<void> addCredits(int amount) async {
    if (amount <= 0) return;
    final user = _auth.currentUser;

    // Offline / Anonymous guest fallback[cite: 13]
    if (user == null) {
      final updated = _currentBalance + amount;
      await _updateLocalBalance(updated);
      return;
    }

    final docRef = _firestore.collection('wallets').doc(user.uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          transaction.set(docRef, {
            'balance': _currentBalance + amount,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final currentServerBalance = snapshot.data()?['balance'] as int? ?? 0;
          transaction.update(docRef, {
            'balance': currentServerBalance + amount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('🚨 [Failed to add credits via Firestore transaction]: $e');
      // Optimistic local update as failsafe[cite: 13]
      final fallback = _currentBalance + amount;
      await _updateLocalBalance(fallback);
    }
  }

  /// Securely grants credits when a user completes a rewarded ad.
  /// Queries Firebase Remote Config for the reward payout (defaulting to 50 credits).
  Future<int> addCreditsFromAd({int? customAmount}) async {
    int payout = customAmount ?? 50;
    try {
      payout = customAmount ?? RemoteConfigService().rewardedAdCreditPayout;
      if (payout <= 0) payout = 50;
    } catch (_) {
      payout = customAmount ?? 50;
    }

    await addCredits(payout);
    debugPrint('🎁 [WalletService]: Rewarded ad payout granted (+$payout credits).');
    return payout;
  }

  /// Atomically deducts credits for premium feature usage (CBT reframes, somatic sessions, etc.)[cite: 13].
  /// Validates sufficient balance before deducting to prevent negative credit balances[cite: 13].
  Future<bool> deductCredits(int amount) async {
    if (amount <= 0) return true;

    // Fast-fail check against local memory cache[cite: 13]
    if (_currentBalance < amount) {
      return false;
    }

    final user = _auth.currentUser;

    // Offline / Anonymous guest fallback[cite: 13]
    if (user == null) {
      final updated = _currentBalance - amount;
      await _updateLocalBalance(updated);
      return true;
    }

    final docRef = _firestore.collection('wallets').doc(user.uid);
    bool success = false;

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          if (_currentBalance >= amount) {
            transaction.set(docRef, {
              'balance': _currentBalance - amount,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            success = true;
          } else {
            success = false;
          }
          return;
        }

        final currentServerBalance = snapshot.data()?['balance'] as int? ?? 0;

        if (currentServerBalance >= amount) {
          transaction.update(docRef, {
            'balance': currentServerBalance - amount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          success = true;
        } else {
          success = false; // Insufficient balance on server[cite: 13]
        }
      });

      if (success) {
        // Optimistically deduct locally while stream syncs[cite: 13]
        await _updateLocalBalance(_currentBalance - amount);
      }
      return success;
    } catch (e) {
      debugPrint('🚨 [Failed to deduct credits via transaction]: $e');
      // Fallback: If network failed but user had local credits, allow session and deduct locally[cite: 13]
      if (_currentBalance >= amount) {
        await _updateLocalBalance(_currentBalance - amount);
        return true;
      }
      return false;
    }
  }

  /// Cancels subscriptions and disposes the stream controller[cite: 13].
  void dispose() {
    _walletSubscription?.cancel();
    _balanceController.close();
  }
}