import 'package:flutter/foundation.dart';

class MarginEngine {
  // Estimated fixed monthly costs distributed per user in USD
  // Includes App server load, Ops, CAC amortization, Marketing, and Tax estimates.
  static const double _fixedMonthlyCostPerUser = 5.00; 
  
  // The absolute minimum profit multiplier the business requires
  static const double _targetProfitMultiplier = 5.0; // 5x Net Profit

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
        print('MarginEngine Error - calculating dynamic pricing: $e');
      }
      // Fail-safe fallback to prevent app-breaking UI crashes during checkout
      return {
        'weekly': 19.99,
        'monthly': 49.99,
        'yearly': 499.99,
      };
    }
  }

  /// Circuit breaker mechanism: Call this BEFORE initiating expensive AI LLM requests.
  /// Evaluates if the current user is draining their margin allowance.
  bool isUnitProfitable({
    required double currentMonthRevenue, 
    required double currentMonthComputeCost
  }) {
    try {
      // If cost is 0 or less, they are infinitely profitable (using cached/free features).
      if (currentMonthComputeCost <= 0) return true;

      // Calculate current ratio
      final currentMarginMultiplier = currentMonthRevenue / currentMonthComputeCost;

      // If the multiplier drops below our target (allowing a strict 10% tolerance buffer),
      // return false to trigger cached/RAG fallback instead of premium LLM calls.
      final threshold = _targetProfitMultiplier * 0.90;

      if (currentMarginMultiplier < threshold) {
         if (kDebugMode) {
            print('MARGIN WARNING: User compute cost ($currentMonthComputeCost) threatens revenue margin ($currentMonthRevenue).');
         }
         return false;
      }

      return true;
    } catch (e) {
      // Fail secure: If calculation fails, assume unprofitable to protect cloud resources
      if (kDebugMode) {
         print('MarginEngine Error - calculating unit profitability: $e');
      }
      return false;
    }
  }

  /// Calculates the exact AI token budget a user has left before triggering the circuit breaker.
  /// Used for UI updates (e.g., "Premium AI requests remaining") and throttling logic.
  int remainingPremiumCalls({
    required double currentMonthRevenue,
    required double currentMonthComputeCost,
    required double averageCostPerCall,
  }) {
    try {
      if (averageCostPerCall <= 0) return 9999; // Infinite if calls are free

      // Max allowed cost to still safely hit the 5x margin
      double maxAllowedCost = currentMonthRevenue / _targetProfitMultiplier;
      double remainingCostAllowance = maxAllowedCost - currentMonthComputeCost;

      // If they exceeded their allowance, return 0
      if (remainingCostAllowance <= 0) return 0;

      return (remainingCostAllowance / averageCostPerCall).floor();
    } catch (e) {
      if (kDebugMode) {
         print('MarginEngine Error - calculating remaining calls: $e');
      }
      return 0; // Protect resources on error
    }
  }
}