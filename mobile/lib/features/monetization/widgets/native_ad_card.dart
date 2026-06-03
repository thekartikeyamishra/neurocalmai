import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: AdMobService.instance.nativeAdUnitId,
      // Seamlessly camouflage the ad to match the NeuroCalm Theme
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: const Color(0xFFF7F9F9), // App surface color
        cornerRadius: 24.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF2A5C5A), // Primary Teal
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF2A5C5A),
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF666666),
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[Native Ad Error]: Failed to load: $error');
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose(); // Strict memory leak prevention
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink(); // Takes up zero space if ad fails/is loading
    }

    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          ),
        ],
      ),
      // Constrain height as required by Google Mobile Ads Native Medium Template
      height: 320, 
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}