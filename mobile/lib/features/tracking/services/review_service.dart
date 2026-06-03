import 'package:in_app_review/in_app_review.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AsoReviewService {
  static final AsoReviewService instance = AsoReviewService._internal();
  final InAppReview _inAppReview = InAppReview.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AsoReviewService._internal();

  /// Psychological Feedback Loop:
  /// Evaluates the user's mood change. If they moved from a negative state
  /// to a highly positive state (e.g., Post-Session Mood >= 8), we trigger the review.
  Future<void> evaluateSessionForReview(int preSessionMood, int postSessionMood) async {
    try {
      // Rule 1: Only trigger if they actually improved and feel great
      if (postSessionMood < 8 || (postSessionMood - preSessionMood) < 2) return;

      // Rule 2: Don't spam them. Check if we've already asked recently.
      String? lastAskedStr = await _storage.read(key: 'last_review_prompt_date');
      if (lastAskedStr != null) {
        DateTime lastAsked = DateTime.parse(lastAskedStr);
        if (DateTime.now().difference(lastAsked).inDays < 30) {
          return; // Asked within the last month, do not annoy them
        }
      }

      // Rule 3: Native OS limits apply, but we request the dialog natively
      if (await _inAppReview.isAvailable()) {
        debugPrint('[ASO Service]: User is highly satisfied. Triggering App Store rating.');
        await _inAppReview.requestReview();
        await _storage.write(key: 'last_review_prompt_date', value: DateTime.now().toIso8601String());
      }
    } catch (e) {
      debugPrint('[ASO Service Error]: $e');
    }
  }
}