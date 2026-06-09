import 'package:flutter/foundation.dart';

/// The MarginEngine enforces strict business profitability rules.
/// It dynamically adjusts psychological pricing and acts as a financial 
/// circuit breaker to guarantee a minimum 5x net profit margin against LLM API costs.
class MarginEngine {
  // Estimated fixed monthly costs distributed per user in USD
  // Includes App server load, Ops, CAC amortization, Marketing, and Tax estimates.
  static const double _fixedMonthlyCostPerUser = 5.00; 
  
  // The absolute minimum profit multiplier the business requires
  static const double _targetProfitMultiplier = 5.0; // 5x Net Profit

  // In-memory state tracking for rapid, synchronous circuit breaking during AI calls.
  // These should be updated upon user login or subscription renewal via Firestore.
  double _currentUserMonthlyRevenue = 49.99; // Default fallback premium tier
  double _currentUserMonthlyComputeCost = 0.0;

  /// Updates the current user's financial state in memory for rapid circuit breaking.
  /// Call this when syncing user profile data from Firestore.
  void updateOperationalState({
    required double currentRevenue, 
    required double currentComputeCost,
  }) {
    _currentUserMonthlyRevenue = currentRevenue;
    _currentUserMonthlyComputeCost = currentComputeCost;
  }

  /// Calculates psychological pricing tiers based on a user's projected compute.
  /// Ensures the business hits a strict 5x margin on the baseline monthly plan.
  Map<String, double> generateDecoyPricing(double projectedMonthlyApiCost) {
    try {
      // Safeguard against negative or invalid projections
      final safeApiCost = projectedMonthlyApiCost < 0 ? 0.0 : projectedMonthlyApiCost;

      double totalCostBasis = _fixedMonthlyCostPerUser + safeApiCost;

      // The base price required to hit 5x margin exactly
      double targetMonthlyPrice = totalCostBasis * _targetProfitMultiplier;

      // Psychological Decoy Pricing Strategy:
      // Weekly: Mathematically terrible (40% of monthly price per week). Makes monthly look smart.
      // Monthly: The baseline target margin.
      // Yearly: Gives 2 months "free", locks in capital upfront, drastically reduces churn.
      return {
        'weekly': double.parse((targetMonthlyPrice * 0.40).toStringAsFixed(2)),
        'monthly': double.parse(targetMonthlyPrice.toStringAsFixed(2)),
        'yearly': double.parse((targetMonthlyPrice * 10.0).toStringAsFixed(2)),
      };
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [MarginEngine Error] - Calculating dynamic pricing: $e');
      }
      // Fail-safe fallback to prevent app-breaking UI crashes during checkout
      return {
        'weekly': 19.99,
        'monthly': 49.99,
        'yearly': 499.99,
      };
    }
  }

  /// Circuit breaker mechanism: Called by AIGateway BEFORE initiating expensive LLM requests.
  /// Evaluates if the current transaction violates the 5x profit margin.
  bool isTransactionProfitable(double expectedTokenCost) {
    try {
      // If the transaction costs nothing (cached or SLM), it is inherently profitable.
      if (expectedTokenCost <= 0.0) return true;

      final projectedTotalCost = _currentUserMonthlyComputeCost + expectedTokenCost;

      // Calculate the projected margin multiplier if this transaction goes through
      final currentMarginMultiplier = _currentUserMonthlyRevenue / projectedTotalCost;

      // If the multiplier drops below our target (allowing a strict 10% tolerance buffer),
      // return false to trigger cached/RAG fallback instead of premium LLM calls.
      final threshold = _targetProfitMultiplier * 0.90;

      if (currentMarginMultiplier < threshold) {
         if (kDebugMode) {
            print('🛡️ [MARGIN WARNING]: Transaction cost (\$${expectedTokenCost.toStringAsFixed(4)}) threatens 5x margin. Dropping to RAG fallback.');
         }
         return false;
      }

      // If profitable, tentatively add to current session cost.
      // Note: In production, ensure this syncs back to Firestore after the actual LLM call completes.
      _currentUserMonthlyComputeCost += expectedTokenCost;

      return true;
    } catch (e) {
      // Fail secure: If calculation fails, assume unprofitable to protect cloud resources from bleeding money.
      if (kDebugMode) {
         print('⚠️ [MarginEngine Error] - Calculating unit profitability: $e');
      }
      return false;
    }
  }

  /// Calculates the exact AI token budget a user has left before triggering the circuit breaker.
  /// Used for UI updates (e.g., "Premium AI requests remaining") and proactive throttling logic.
  int remainingPremiumCalls(double averageCostPerCall) {
    try {
      if (averageCostPerCall <= 0) return 9999; // Infinite if calls are free

      // Max allowed compute cost to still safely hit the 5x margin
      double maxAllowedCost = _currentUserMonthlyRevenue / _targetProfitMultiplier;
      double remainingCostAllowance = maxAllowedCost - _currentUserMonthlyComputeCost;

      // If they exceeded their financial allowance, return 0
      if (remainingCostAllowance <= 0) return 0;

      return (remainingCostAllowance / averageCostPerCall).floor();
    } catch (e) {
      if (kDebugMode) {
         print('⚠️ [MarginEngine Error] - Calculating remaining calls: $e');
      }
      return 0; // Protect resources on error
    }
  }
}