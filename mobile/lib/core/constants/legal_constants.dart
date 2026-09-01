/// Centralized legal strings and compliance texts.
/// These constants ensure strict adherence to Google Play's 
/// Health Content and Services policies and User-Generated Content (UGC) policies.
class LegalConstants {
  // =========================================================================
  // HEALTH & MEDICAL DISCLAIMERS (Google Play Health App Compliance)
  // =========================================================================

  /// The short medical disclaimer to be shown under AI tools and Quick Actions.
  static const String medicalDisclaimerShort = 
      "Disclaimer: This platform is not a medical device. It does not diagnose, treat, or prevent any condition. Use for general wellness and relaxation only.";

  /// The full medical disclaimer for onboarding and the subscription paywall.
  static const String medicalDisclaimerFull = 
      "NeuroCalm AI is designed for personal wellness, self-reflection, and relaxation. "
      "It is not a medical device, nor is it a substitute for professional medical advice, "
      "psychiatric diagnosis, or clinical therapy. If you are experiencing a mental health crisis, "
      "please contact your local emergency services or a licensed mental health professional immediately.";

  // =========================================================================
  // USER-GENERATED CONTENT (UGC) EULA (Google Play UGC Compliance)
  // =========================================================================

  /// The mandatory User-Generated Content End-User License Agreement.
  /// Users must accept this before participating in or creating any communities.
  static const String ugcEulaAgreement = 
      "By using the Community features, you agree to our Terms of Use. "
      "We maintain a zero-tolerance policy for harassment, hate speech, explicit content, "
      "or abusive behavior. Any user found violating these rules will be permanently banned. "
      "You are encouraged to use the in-app reporting tools to flag objectionable content or block users.";

  // =========================================================================
  // COMMUNITY FACILITATOR CHARTER
  // =========================================================================

  /// The charter a user must explicitly accept before they are allowed to host a local chapter.
  /// Protects the platform from liability regarding illegal gatherings or pseudo-medical advice.
  static const String hostFacilitatorCharter = 
      "As a Community Facilitator, I acknowledge:\n"
      "1. These gatherings are casual peer-support social meetups, not group therapy.\n"
      "2. I will not provide medical advice, diagnosis, or therapeutic treatment.\n"
      "3. All events must be held in safe, public venues (e.g., cafes, parks, libraries).\n"
      "4. I will actively maintain a safe environment and report any harassment or violations.";

  /// The liability waiver required before posting an individual event.
  static const String eventLiabilityWaiver = 
      "I certify this event is in a public place. I will facilitate casual conversation only, "
      "without providing medical treatment or therapeutic claims.";

  // =========================================================================
  // EXTERNAL COMPLIANCE LINKS
  // =========================================================================
  
  // Replace these with your actual production URLs hosted on Vercel or your website
  static const String privacyPolicyUrl = "https://neurocalmai.com/privacy";
  static const String termsOfServiceUrl = "https://neurocalmai.com/terms";
}