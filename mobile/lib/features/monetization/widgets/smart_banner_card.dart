import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SmartBannerCard extends StatefulWidget {
  const SmartBannerCard({super.key});

  @override
  State<SmartBannerCard> createState() => _SmartBannerCardState();
}

class _SmartBannerCardState extends State<SmartBannerCard> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  // Uses Google's official test IDs in debug mode, and your production IDs otherwise.
  String get _bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    return Platform.isAndroid
        ? dotenv.env['ADMOB_BANNER_ANDROID'] ?? ''
        : dotenv.env['ADMOB_BANNER_IOS'] ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) {
      _loadAnchoredAdaptiveBanner();
    }
  }

  Future<void> _loadAnchoredAdaptiveBanner() async {
    // Dynamically query orientation sizes to calculate safe screen ratios off-thread
    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            MediaQuery.of(context).size.width.truncate());

    if (size == null) return;

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isAdLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('⚠️ [AdMob Smart Banner]: Refused to map buffer layout: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Takes up $0 cost/space prior to compile delivery, preventing ugly blank squares
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink(); 
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16.0),
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}