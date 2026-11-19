import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google UMP consent (GDPR/EEA, UK, Switzerland + US state privacy laws).
///
/// Since Jan 2024 Google requires a certified CMP for EEA/UK traffic. Without
/// it, AdMob serves limited or no ads there, which silently kills revenue
/// from the highest-paying regions. Outside regulated regions the form is
/// never shown and this completes instantly.
class AdConsentService {
  AdConsentService._();
  static final AdConsentService instance = AdConsentService._();

  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  Completer<bool>? _inFlight;

  bool get canRequestAds => _canRequestAds;

  /// Whether Settings must show a "Privacy & ad choices" entry (legal req.).
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// Requests the latest consent info and shows the form only if required.
  /// Never throws; times out so a slow network can't block the app.
  Future<bool> gatherConsent() {
    if (_inFlight != null) return _inFlight!.future;
    final completer = Completer<bool>();
    _inFlight = completer;

    Future<void> finish() async {
      try {
        _canRequestAds = await ConsentInformation.instance.canRequestAds();
        _privacyOptionsRequired =
            await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
                PrivacyOptionsRequirementStatus.required;
      } catch (e) {
        debugPrint('⚠️ [Consent]: status read failed: $e');
      }
      if (!completer.isCompleted) completer.complete(_canRequestAds);
      _inFlight = null;
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
            if (error != null) {
              debugPrint('⚠️ [Consent]: form error ${error.errorCode}: ${error.message}');
            }
            finish();
          });
        },
        (FormError error) {
          debugPrint('⚠️ [Consent]: info update failed: ${error.message}');
          finish(); // Previous session's consent may still allow ads.
        },
      );
    } catch (e) {
      debugPrint('⚠️ [Consent]: unexpected $e');
      finish();
    }

    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => _canRequestAds,
    );
  }

  /// Opens the privacy options form (Settings > Privacy & ad choices).
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (error != null) debugPrint('⚠️ [Consent]: ${error.message}');
      });
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('⚠️ [Consent]: privacy options failed: $e');
    }
  }
}
