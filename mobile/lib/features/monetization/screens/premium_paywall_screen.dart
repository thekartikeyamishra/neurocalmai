import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/remote_config_service.dart';

import '../../../core/services/iap_service.dart';
import '../../../core/services/wallet_service.dart';
import '../../dashboard/screens/dashboard_screen.dart';

/// Premium paywall.
///
/// FIX: the previous screen had NO purchase path — "Unlock All Features
/// Instantly" just closed the screen (and fired an interstitial on the way
/// out, which punishes the exact users most likely to pay). It now lists the
/// RevenueCat offering (localized prices from Play), purchases, restores,
/// and never shows an ad.
class PremiumPaywallScreen extends ConsumerStatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  ConsumerState<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends ConsumerState<PremiumPaywallScreen> {
  static const _bg = Color(0xFF0F172A);
  static const _accent = Color(0xFF38BDF8);
  static const _cta = Color(0xFF2A5C5A);

  List<Package> _packages = [];
  Package? _selected;
  bool _loading = true;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final offerings = await IAPService().getOfferings();
    final all = offerings?.current?.availablePackages ?? const <Package>[];
    // Subscriptions + lifetime only (credit sachets live in the wallet dialog).
    final plans = all.where((p) => !p.storeProduct.identifier.startsWith('sachet_')).toList()
      ..sort((a, b) => _rank(a).compareTo(_rank(b)));
    if (!mounted) return;
    setState(() {
      _packages = plans;
      _selected = plans.isNotEmpty ? plans.first : null;
      _loading = false;
    });
  }

  // Annual first (best value + lowest churn), then monthly, then lifetime.
  int _rank(Package p) {
    switch (p.packageType) {
      case PackageType.annual:
        return 0;
      case PackageType.monthly:
        return 1;
      case PackageType.lifetime:
        return 2;
      default:
        return 3;
    }
  }

  String _label(Package p) {
    switch (p.packageType) {
      case PackageType.annual:
        return 'Yearly';
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.lifetime:
        return 'Lifetime';
      default:
        return p.storeProduct.title.split('(').first.trim();
    }
  }

  String? _badge(Package p) {
    if (p.packageType == PackageType.annual) {
      final monthly = _packages.where((x) => x.packageType == PackageType.monthly).toList();
      if (monthly.isNotEmpty) {
        final m = monthly.first.storeProduct.price * 12;
        final a = p.storeProduct.price;
        if (m > 0 && a < m) return 'Save ${(((m - a) / m) * 100).round()}%';
      }
      return 'Best value';
    }
    if (p.packageType == PackageType.lifetime) return 'Pay once';
    return null;
  }

  Future<void> _purchase() async {
    final pkg = _selected;
    if (pkg == null || _purchasing) return;
    HapticFeedback.mediumImpact();
    setState(() => _purchasing = true);
    final ok = await IAPService().purchasePackage(pkg);
    if (!mounted) return;
    setState(() => _purchasing = false);
    if (ok) {
      WalletService().sync();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to Premium. Ads are gone and every tool is unlocked.')),
      );
      _close();
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    final ok = await IAPService().restorePurchases();
    if (!mounted) return;
    setState(() => _purchasing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Premium restored.' : 'No previous purchase found for this Google account.'),
    ));
    if (ok) _close();
  }

  void _close() {
    HapticFeedback.lightImpact();
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: _close,
                tooltip: 'Continue with free',
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 56, color: _accent),
                  const SizedBox(height: 16),
                  const Text('Calm, without limits',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                  const SizedBox(height: 8),
                  Text('Less than a cup of coffee a month. Cancel anytime in Google Play.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15, height: 1.4)),
                  const SizedBox(height: 28),
                  _benefit(Icons.all_inclusive_rounded, 'Unlimited reflections', 'No daily cap on voice, journal and chat sessions.'),
                  _benefit(Icons.block_rounded, 'Zero ads, ever', 'Nothing between you and a calmer mind.'),
                  _benefit(Icons.lock_open_rounded, 'Every tool unlocked', 'Voice reframe, somatic grounding and PDF export — no credits needed.'),
                  _benefit(Icons.lock_rounded, 'Still private', 'Your journal stays on your device. Always.'),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: _accent)),
                    )
                  else if (_packages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Plans could not be loaded. Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    )
                  else
                    ..._packages.map(_planTile),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _selected == null || _purchasing ? null : _purchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cta,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: _purchasing
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          _selected == null ? 'Unavailable' : 'Continue · ${_selected!.storeProduct.priceString}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: _purchasing ? null : _restore, child: const Text('Restore purchase', style: TextStyle(color: Colors.white60))),
                TextButton(onPressed: _close, child: const Text('Continue free', style: TextStyle(color: Colors.white60))),
              ],
            ),
            // Store-required subscription disclosure (Apple 3.1.2 / Google Play).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _selected?.packageType == PackageType.lifetime
                    ? 'One-time purchase. No subscription.'
                    : 'Subscriptions renew automatically at the price shown unless cancelled at least 24 hours before '
                        'the end of the period. Manage or cancel any time in your Google Play or App Store account.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11.5, height: 1.4),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(RemoteConfigService().termsUrl), mode: LaunchMode.externalApplication),
                  child: const Text('Terms of Use', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(RemoteConfigService().privacyPolicyUrl), mode: LaunchMode.externalApplication),
                  child: const Text('Privacy Policy', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _planTile(Package p) {
    final selected = identical(p, _selected);
    final badge = _badge(p);
    return GestureDetector(
      onTap: () => setState(() => _selected = p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.10 : 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? _accent : Colors.white12, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? _accent : Colors.white38),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_label(p),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
                child: Text(badge, style: const TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            Text(p.storeProduct.priceString,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: _accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5)),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
