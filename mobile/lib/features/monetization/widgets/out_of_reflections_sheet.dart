import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/services/wallet_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../wallet/presentation/wallet_topup_dialog.dart';
import '../services/admob_service.dart';

/// Shown at the exact moment of intent (user wants another reflection and
/// the free daily allowance is used). This is where rewarded ads earn the
/// most and feel the fairest: a clear, optional trade, never a forced ad.
class OutOfReflectionsSheet {
  OutOfReflectionsSheet._();
  static bool _open = false;

  static Future<void> show() async {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null || _open) return;
    _open = true;
    try {
      await showModalBottomSheet<void>(
        context: ctx,
        backgroundColor: AppTokens.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetCtx) => const _Body(),
      );
    } finally {
      _open = false;
    }
  }
}

class _Body extends StatefulWidget {
  const _Body();
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _busy = false;

  void _watch() {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    AdMobService.instance.showRewardedAd(
      onEarnedReward: () {},
      onEarnedRewardWithNonce: (nonce) async {
        final granted = await WalletService().claimAdReward(nonce);
        final messenger = ScaffoldMessenger.maybeOf(appNavigatorKey.currentContext ?? context);
        messenger?.showSnackBar(SnackBar(
          content: Text(granted > 0
              ? '+$granted credits added. Tap send again to continue.'
              : "Today's sponsor limit is reached — your free reflections refresh tomorrow."),
        ));
      },
      onAdClosed: () {
        if (mounted) Navigator.of(context).maybePop();
      },
      onAdFailed: () {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('No sponsor available right now. Please try again in a minute.')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final reward = WalletService().rewardCredits;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("You've used today's free reflections",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppTokens.onSurface)),
            const SizedBox(height: 6),
            Text('They refresh tomorrow. Want to keep going now?',
                style: TextStyle(fontSize: 14, color: AppTokens.onSurfaceVariant.withValues(alpha: 0.9))),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: AdMobService.instance.isRewardedAdReady,
              builder: (context, ready, _) => SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: ready && !_busy ? _watch : null,
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: Text(ready ? 'Watch a short sponsor message (+$reward credits)' : 'Finding a sponsor…'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  final ctx = appNavigatorKey.currentContext;
                  if (ctx != null) {
                    showDialog(context: ctx, builder: (_) => const WalletTopUpDialog());
                  }
                },
                child: const Text('Get credits or go Premium'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
