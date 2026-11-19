import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/admob_service.dart';

/// Adaptive anchored banner. FIX: the previous version used an empty ad unit
/// id in release whenever `.env` lacked ADMOB_BANNER_ANDROID, so it never
/// loaded, and it was not placed on any screen. It now resolves ids through
/// AdConfig, respects premium/consent/grace rules and is placed on browse
/// screens.
class SmartBannerCard extends StatefulWidget {
  const SmartBannerCard({super.key});

  @override
  State<SmartBannerCard> createState() => _SmartBannerCardState();
}

class _SmartBannerCardState extends State<SmartBannerCard> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _requested = false;

  int _width = 0;

  @override
  void initState() {
    super.initState();
    AdMobService.instance.sdkReadyNotifier.addListener(_tryLoad);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _width = MediaQuery.of(context).size.width.truncate();
    _tryLoad();
  }

  void _tryLoad() {
    if (!mounted || _requested || _width <= 0) return;
    if (!AdMobService.instance.canServeBanner) return;
    _requested = true;
    _load(_width);
  }

  Future<void> _load(int width) async {
    try {
      final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      if (size == null || !mounted) return;
      final ad = BannerAd(
        adUnitId: AdMobService.instance.bannerAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) return; // dispose() already released it
            setState(() => _isAdLoaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('⚠️ [Banner]: ${error.code} ${error.message}');
            if (!mounted) return;
            ad.dispose();
            if (_bannerAd == ad) _bannerAd = null;
          },
        ),
      );
      _bannerAd = ad;
      await ad.load();
    } catch (e) {
      debugPrint('⚠️ [Banner]: load skipped: $e');
    }
  }

  @override
  void dispose() {
    AdMobService.instance.sdkReadyNotifier.removeListener(_tryLoad);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (!_isAdLoaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
