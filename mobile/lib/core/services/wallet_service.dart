import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Credit wallet — SERVER-AUTHORITATIVE.
///
/// Security fix: the old client wrote its own balance to Firestore, so any
/// user with a proxy could give themselves unlimited credits, and purchased
/// sachets were credited to a different document than the one the app read.
/// Now every balance change happens in Cloud Functions (walletSync,
/// walletSpend, claimAdReward, RevenueCat webhook, AdMob SSV). The client
/// only reads (real-time) and caches the last known value for instant UI.
class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal() {
    _loadCachedBalance();
  }

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _cacheKey = 'wallet_cached_balance_v3';

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _walletSubscription;
  StreamSubscription<User?>? _authSubscription;
  final StreamController<int> _balanceController = StreamController<int>.broadcast();
  Stream<int> get balanceStream => _balanceController.stream;

  int _currentBalance = 0;
  int get currentBalance => _currentBalance;

  int _freeRemaining = 5;
  int _freeDaily = 5;
  int _rewardCredits = 2;
  bool _serverPremium = false;
  String? _listeningUid;

  /// Free AI reflections left today (server value from last sync/reply).
  int get freeRemaining => _freeRemaining;
  int get freeDaily => _freeDaily;
  int get rewardCredits => _rewardCredits;
  bool get isServerPremium => _serverPremium;

  Future<void> _loadCachedBalance() async {
    try {
      final cached = await _secureStorage.read(key: _cacheKey);
      final value = int.tryParse(cached ?? '');
      if (value != null) _emit(value);
    } catch (e) {
      debugPrint('⚠️ [Wallet]: cache read failed: $e');
    }
  }

  void _emit(int balance) {
    if (balance < 0) balance = 0;
    _currentBalance = balance;
    if (!_balanceController.isClosed) _balanceController.add(balance);
    _secureStorage.write(key: _cacheKey, value: '$balance').catchError((Object _) {});
  }

  /// Starts the real-time listener and syncs the economy snapshot.
  /// Safe to call many times; re-binds automatically when the user changes.
  Future<void> init() async {
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && user.uid != _listeningUid) {
        _bind(user.uid);
        sync();
      }
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _bind(user.uid);
    unawaited(sync());
  }

  void _bind(String uid) {
    if (_listeningUid == uid && _walletSubscription != null) return;
    _walletSubscription?.cancel();
    _listeningUid = uid;
    _walletSubscription = FirebaseFirestore.instance
        .collection('wallets')
        .doc(uid)
        .snapshots()
        .listen(
      (snap) {
        final data = snap.data();
        if (data != null && data['balance'] is num) {
          _emit((data['balance'] as num).toInt());
        }
      },
      onError: (Object e) => debugPrint('⚠️ [Wallet]: listener error (offline cache in use): $e'),
    );
  }

  /// Creates the wallet server-side if needed and refreshes allowance info.
  Future<void> sync() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final res = await _functions
          .httpsCallable('walletSync', options: HttpsCallableOptions(timeout: const Duration(seconds: 15)))
          .call<dynamic>();
      final data = Map<String, dynamic>.from(res.data as Map);
      _applyEconomy(data);
      if (data['balance'] is num) _emit((data['balance'] as num).toInt());
    } catch (e) {
      debugPrint('⚠️ [Wallet]: sync failed (will retry next launch): $e');
    }
  }

  void _applyEconomy(Map<String, dynamic> data) {
    if (data['freeRemaining'] is num) _freeRemaining = (data['freeRemaining'] as num).toInt();
    if (data['freeDaily'] is num) _freeDaily = (data['freeDaily'] as num).toInt();
    if (data['rewardCredits'] is num) _rewardCredits = (data['rewardCredits'] as num).toInt();
    if (data['isPremium'] is bool) _serverPremium = data['isPremium'] as bool;
  }

  /// Called by the AI gateway after each metered reply.
  void applyMeterUpdate({int? freeRemaining, int? balance}) {
    if (freeRemaining != null) _freeRemaining = freeRemaining;
    if (balance != null) _emit(balance);
  }

  static String _requestId() {
    final r = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(20, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Spends credits for a premium tool. Returns false when the balance is
  /// insufficient or the server can't be reached (tools need the cloud anyway).
  Future<bool> deductCredits(int amount, {String reason = 'tool'}) async {
    if (amount <= 0) return true;
    if (FirebaseAuth.instance.currentUser == null) return false;
    try {
      final res = await _functions
          .httpsCallable('walletSpend', options: HttpsCallableOptions(timeout: const Duration(seconds: 15)))
          .call<dynamic>({'amount': amount, 'requestId': _requestId(), 'reason': reason});
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['balance'] is num) _emit((data['balance'] as num).toInt());
      return data['ok'] == true;
    } catch (e) {
      debugPrint('🚨 [Wallet]: spend failed: $e');
      return false;
    }
  }

  /// Claims credits for a completed rewarded ad. Returns credits granted.
  Future<int> claimAdReward(String nonce) async {
    try {
      final res = await _functions
          .httpsCallable('claimAdReward', options: HttpsCallableOptions(timeout: const Duration(seconds: 15)))
          .call<dynamic>({'nonce': nonce});
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['balance'] is num) _emit((data['balance'] as num).toInt());
      if (data['credits'] is num) _rewardCredits = (data['credits'] as num).toInt();
      if (data['credited'] == true) return _rewardCredits;
      if (data['pending'] == true) return _rewardCredits; // arrives via SSV
      return 0;
    } catch (e) {
      debugPrint('🚨 [Wallet]: ad reward claim failed: $e');
      return 0;
    }
  }

  /// Deprecated: credits can no longer be added from the client. Purchases
  /// are credited by the RevenueCat webhook; this only refreshes the state.
  Future<void> addCredits(int amount) => sync();

  /// Deprecated shim kept for older call sites; prefer [claimAdReward].
  Future<int> addCreditsFromAd({int? customAmount}) async {
    final granted = await claimAdReward(AdNonce.generate());
    return granted;
  }

  void dispose() {
    _walletSubscription?.cancel();
    _authSubscription?.cancel();
    _balanceController.close();
  }
}

/// Small helper so legacy call sites can create a reward nonce.
class AdNonce {
  static String generate() {
    final r = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
