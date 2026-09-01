import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'review_service.dart';

// ============================================================================
// DATA MODEL: Milestone State
// ============================================================================
class MilestoneState {
  final int totalXP;
  final int currentLevel;
  final Set<String> unlockedBadges;
  
  /// Holds badges that were just unlocked during the current session.
  /// The UI consumes this list to trigger the high-fidelity confetti overlays, 
  /// then clears it to prevent duplicate celebrations.
  final List<String> newlyUnlockedBadges;

  MilestoneState({
    required this.totalXP,
    required this.currentLevel,
    required this.unlockedBadges,
    this.newlyUnlockedBadges = const [],
  });

  MilestoneState copyWith({
    int? totalXP,
    int? currentLevel,
    Set<String>? unlockedBadges,
    List<String>? newlyUnlockedBadges,
  }) {
    return MilestoneState(
      totalXP: totalXP ?? this.totalXP,
      currentLevel: currentLevel ?? this.currentLevel,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      newlyUnlockedBadges: newlyUnlockedBadges ?? this.newlyUnlockedBadges,
    );
  }
}

// ============================================================================
// CORE ENGINE: Ethical Gamification & Progression
// ============================================================================
/// Manages experience points (XP), leveling, and badge unlocking on a background 
/// thread to ensure the main UI never stutters or drops frames.
class MilestoneNotifier extends AsyncNotifier<MilestoneState> {
  static const String _xpKey = 'user_total_xp';
  static const String _badgesKey = 'user_unlocked_badges';
  
  // Mathematical scaling for leveling (e.g., Level 1 = 100 XP, Level 2 = 250 XP)
  int _calculateLevel(int xp) {
    if (xp < 100) return 1;
    if (xp < 300) return 2;
    if (xp < 600) return 3;
    if (xp < 1000) return 4;
    if (xp < 1500) return 5;
    return 5 + ((xp - 1500) / 1000).floor(); // Infinite scaling endgame
  }

  @override
  Future<MilestoneState> build() async {
    return _loadProgress();
  }

  Future<MilestoneState> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final xp = prefs.getInt(_xpKey) ?? 0;
      final badgesList = prefs.getStringList(_badgesKey) ?? [];
      
      return MilestoneState(
        totalXP: xp,
        currentLevel: _calculateLevel(xp),
        unlockedBadges: badgesList.toSet(),
        newlyUnlockedBadges: [],
      );
    } catch (e) {
      debugPrint('[MilestoneService Error]: Failed to load progress - $e');
      return MilestoneState(totalXP: 0, currentLevel: 1, unlockedBadges: {});
    }
  }

  /// Grants XP progressively. Focuses on rewarding the *outcome* and *action*,
  /// rather than manipulating time-in-app.
  Future<void> grantXP(int amount, String actionContext) async {
    if (amount <= 0) return;

    final currentState = state.value;
    if (currentState == null) return;

    final newXP = currentState.totalXP + amount;
    final newLevel = _calculateLevel(newXP);
    
    final newlyUnlocked = <String>[];
    final updatedBadges = Set<String>.from(currentState.unlockedBadges);

    // ------------------------------------------------------------------------
    // BADGE EVALUATION LOGIC
    // ------------------------------------------------------------------------
    // Milestone: First Step (Immediate gratification)
    if (newXP >= 50 && !updatedBadges.contains('First Step')) {
      newlyUnlocked.add('First Step');
      updatedBadges.add('First Step');
    }
    
    // Milestone: Cognitive Explorer (Sustained engagement)
    if (newXP >= 300 && !updatedBadges.contains('Cognitive Explorer')) {
      newlyUnlocked.add('Cognitive Explorer');
      updatedBadges.add('Cognitive Explorer');
    }

    // Milestone: Level Up (Continuous progression)
    if (newLevel > currentState.currentLevel) {
      newlyUnlocked.add('Level $newLevel Reached');
      HapticFeedback.heavyImpact(); // Physiological anchoring for level ups
    }

    // ------------------------------------------------------------------------
    // PERSISTENCE & SIDE-EFFECTS
    // ------------------------------------------------------------------------
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Fire-and-forget writes to prevent blocking
      prefs.setInt(_xpKey, newXP).ignore();
      prefs.setStringList(_badgesKey, updatedBadges.toList()).ignore();

      // If a major milestone was hit, trigger the App Store rating loop ethically.
      // We only ask for reviews when the user feels accomplished.
      if (newlyUnlocked.isNotEmpty) {
        AsoReviewService.instance.evaluateMilestoneForReview().ignore();
      }

      state = AsyncValue.data(
        currentState.copyWith(
          totalXP: newXP,
          currentLevel: newLevel,
          unlockedBadges: updatedBadges,
          // Append to any existing newly unlocked badges that haven't been consumed yet
          newlyUnlockedBadges: [...currentState.newlyUnlockedBadges, ...newlyUnlocked],
        ),
      );

      debugPrint('🌟 [MilestoneEngine]: Granted $amount XP for $actionContext. Total: $newXP');
    } catch (e) {
      debugPrint('[MilestoneService Error]: Failed to save granted XP - $e');
    }
  }

  /// Called by the UI (e.g., MilestoneCelebrationScreen) after the user has 
  /// seen the confetti and badge animation, clearing the queue.
  void consumeNewlyUnlockedBadges() {
    final currentState = state.value;
    if (currentState != null && currentState.newlyUnlockedBadges.isNotEmpty) {
      state = AsyncValue.data(
        currentState.copyWith(newlyUnlockedBadges: []),
      );
    }
  }

  /// Privacy-first wipe of all progression data
  Future<void> clearAllProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_xpKey);
      await prefs.remove(_badgesKey);
      
      state = AsyncValue.data(
        MilestoneState(totalXP: 0, currentLevel: 1, unlockedBadges: {}),
      );
      debugPrint('🧹 [MilestoneEngine]: Progression data securely erased.');
    } catch (e) {
      debugPrint('[MilestoneService Error]: Failed to wipe progress - $e');
    }
  }
}

/// Global Riverpod Provider for UI consumption
final milestoneProvider = AsyncNotifierProvider<MilestoneNotifier, MilestoneState>(() {
  return MilestoneNotifier();
});