// cSpell:disable
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/services/wallet_service.dart';
import '../services/admob_service.dart';

/// A premium, non-intrusive value-exchange widget.
/// Offers the user the choice to watch a sponsored message in exchange for 
/// wallet credits, drastically reducing user churn compared to forced banner ads.
class SponsorRewardCard extends StatefulWidget {
  const SponsorRewardCard({super.key});

  @override
  State<SponsorRewardCard> createState() => _SponsorRewardCardState();
}

class _SponsorRewardCardState extends State<SponsorRewardCard> {
  bool _isAdShowing = false;
  late int _rewardAmount;

  @override
  void initState() {
    super.initState();
    // Server-reported payout (authoritative), Remote Config as display fallback.
    final serverValue = WalletService().rewardCredits;
    _rewardAmount = serverValue > 0 ? serverValue : RemoteConfigService().rewardedAdCreditPayout;
  }

  void _handleWatchAd() {
    if (!AdMobService.instance.isRewardedAdReady.value || _isAdShowing) return;

    HapticFeedback.selectionClick();
    setState(() => _isAdShowing = true);

    AdMobService.instance.showRewardedAd(
      onEarnedReward: () {},
      onEarnedRewardWithNonce: (nonce) async {
        // Server-verified, capped, idempotent credit grant.
        final granted = await WalletService().claimAdReward(nonce);
        if (granted > 0) _rewardAmount = granted;

        if (mounted && granted > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12.0),
                  Text(
                    'Sponsor appreciated! +$_rewardAmount Credits',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981), // Emerald Success
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Thanks! You've reached today's sponsor limit — it resets tomorrow."),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onAdClosed: () {
        if (mounted) setState(() => _isAdShowing = false);
      },
      onAdFailed: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to load the sponsor message. Please try again later.'),
              backgroundColor: AppTokens.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppTokens.surfaceContainer,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: AppTokens.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTokens.primary.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: AppTokens.primaryContainer,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppTokens.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mindful Sponsor",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTokens.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      "Earn $_rewardAmount credits for your journey.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTokens.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),
          Text(
            "Watch a short message from our mindful sponsors to top up your wallet instantly. Your support keeps the core AI therapy engine accessible to everyone.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: AppTokens.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24.0),
          
          // Reactive Button bound to the AdMob Service readiness state
          ValueListenableBuilder<bool>(
            valueListenable: AdMobService.instance.isRewardedAdReady,
            builder: (context, isReady, child) {
              return SizedBox(
                width: double.infinity,
                height: 54.0,
                child: ElevatedButton.icon(
                  onPressed: (isReady && !_isAdShowing) ? _handleWatchAd : null,
                  icon: _isAdShowing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Icon(
                          isReady ? Icons.play_circle_fill_rounded : Icons.hourglass_empty_rounded,
                          size: 22,
                        ),
                  label: Text(
                    _isAdShowing 
                        ? 'Playing...' 
                        : (isReady ? 'Watch to Earn' : 'Finding Sponsor...'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTokens.onSurfaceVariant.withValues(alpha: 0.2),
                    disabledForegroundColor: AppTokens.onSurfaceVariant,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
// cSpell:enable