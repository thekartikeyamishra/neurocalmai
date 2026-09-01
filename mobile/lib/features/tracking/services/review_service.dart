import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A production-ready App Store Optimization (ASO) and review gateway.
/// This service intercepts users during peak psychological moments (e.g., successful 
/// cognitive reframes or gamified milestones) to request a review, ensuring a high 
/// 5-star rating conversion rate while preventing user annoyance.
class AsoReviewService {
  // Singleton instance
  static final AsoReviewService instance = AsoReviewService._internal();
  
  final InAppReview _inAppReview = InAppReview.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AsoReviewService._internal();

  /// Psychological Feedback Loop:
  /// Triggers the native OS review prompt only if the user has reached a "Hooked" 
  /// state (e.g., completed at least 3 successful cognitive investments).
  /// This protects the app's rating by ensuring only satisfied, recurring users are prompted.
  Future<void> evaluateSessionForReview() async {
    try {
      // Safely read the investment metric saved by the HabitLoopService
      final prefs = await SharedPreferences.getInstance();
      final int totalInvestments = prefs.getInt('total_investments') ?? 0;
      
      // Rule 1: Do not prompt brand new or unhooked users. They are more likely to churn or rate poorly.
      if (totalInvestments < 3) return;

      await _requestReviewIfEligible('High Satisfaction Session');
    } catch (e) {
      debugPrint('🚨 [ASO Service Error - Session]: $e');
    }
  }

  /// Milestone Feedback Loop:
  /// Triggers when the user hits a significant gamified milestone (e.g., a 7-day streak 
  /// or unlocking a major achievement). Captures them at a high-value moment.
  Future<void> evaluateMilestoneForReview() async {
    try {
      await _requestReviewIfEligible('Milestone Achievement');
    } catch (e) {
      debugPrint('🚨 [ASO Service Error - Milestone]: $e');
    }
  }

  /// Core logic handling OS-level gating and anti-spam cooldowns.
  Future<void> _requestReviewIfEligible(String triggerSource) async {
    try {
      // Rule 2: Don't spam the user. Check the encrypted ledger to see if we've asked recently.
      String? lastAskedStr = await _storage.read(key: 'last_review_prompt_date');
      
      if (lastAskedStr != null) {
        DateTime lastAsked = DateTime.parse(lastAskedStr);
        // Extended cooldown to 30 days to align with ethical gamification and premium UX
        if (DateTime.now().difference(lastAsked).inDays < 30) {
          return;
        }
      }

      // Rule 3: Native OS limits apply (iOS limits prompts to 3x per 365 days), 
      // but we safely request the dialog natively.
      if (await _inAppReview.isAvailable()) {
        debugPrint('⭐ [ASO Service]: $triggerSource. Triggering native App Store rating.');
        
        await _inAppReview.requestReview();
        
        // Record the exact time we prompted them to enforce the cooldown loop
        await _storage.write(
          key: 'last_review_prompt_date', 
          value: DateTime.now().toIso8601String(),
        );
      } else {
        debugPrint('⚠️ [ASO Service]: In-App Review API is currently unavailable on this device.');
      }
    } catch (e) {
      debugPrint('🚨 [ASO Review Request Error]: $e');
    }
  }
}