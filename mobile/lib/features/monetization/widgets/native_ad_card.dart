import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

/// Native ad styled to the NeuroCalm surface, clearly labelled "Sponsored"
/// (policy requirement, and honest labelling protects trust/retention).
/// Renders nothing for premium users, during the ad-free first session, or
/// when no ad is available — never a blank box.
class NativeAdCard extends StatefulWidget {
  final bool compact;
  const NativeAdCard({super.key, this.compact = false});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    if (AdMobService.instance.canServeNative) {
      _loadNativeAd();
    } else {
      AdMobService.instance.sdkReadyNotifier.addListener(_onSdkReady);
    }
  }

  void _onSdkReady() {
    if (!mounted || _nativeAd != null) return;
    if (AdMobService.instance.canServeNative) {
      AdMobService.instance.sdkReadyNotifier.removeListener(_onSdkReady);
      _loadNativeAd();
    }
  }

  void _loadNativeAd() {
    if (!mounted) return;
    _attempts++;
    final ad = NativeAd(
      adUnitId: AdMobService.instance.nativeAdUnitId,
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.compact ? TemplateType.small : TemplateType.medium,
        mainBackgroundColor: const Color(0xFFFFFFFF),
        cornerRadius: 20.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF2F5244),
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF1E293B),
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF64748B),
          style: NativeTemplateFontStyle.normal,
          size: 13.0,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return; // dispose() already released it
          setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          if (!mounted) return; // dispose() already released it
          ad.dispose();
          if (_nativeAd == ad) _nativeAd = null;
          if (_attempts < 2) {
            Future.delayed(const Duration(seconds: 20), _loadNativeAd);
          }
        },
      ),
      request: const AdRequest(),
    );
    _nativeAd = ad;
    ad.load();
  }

  @override
  void dispose() {
    AdMobService.instance.sdkReadyNotifier.removeListener(_onSdkReady);
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _nativeAd;
    if (!_isAdLoaded || ad == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x142F5244)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'Sponsored',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.4),
            ),
          ),
          SizedBox(
            height: widget.compact ? 110 : 310,
            width: double.infinity,
            child: AdWidget(ad: ad),
          ),
        ],
      ),
    );
  }
}
