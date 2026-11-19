import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../services/referral_service.dart';

/// Give-get invite card: both people get credits. Compact so it never
/// competes with the core "start a session" action.
class InviteFriendsCard extends StatefulWidget {
  const InviteFriendsCard({super.key});

  @override
  State<InviteFriendsCard> createState() => _InviteFriendsCardState();
}

class _InviteFriendsCardState extends State<InviteFriendsCard> {
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    final ok = await ReferralService.instance.shareInvite();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to the internet to create your invite link.')),
      );
    }
  }

  Future<void> _enterCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Have an invite code?'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          decoration: const InputDecoration(hintText: 'e.g. K7M2QXA'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Apply')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    final message = await ReferralService.instance.redeem(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final get = ReferralService.instance.referrerCredits;
    final give = ReferralService.instance.receiverCredits;
    return Container(
      padding: const EdgeInsets.all(AppTokens.spacing16),
      decoration: BoxDecoration(
        color: AppTokens.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: AppTokens.onSurfaceVariant.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTokens.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: AppTokens.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Calm is better shared',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTokens.onSurface)),
                const SizedBox(height: 2),
                Text('Friend gets $give credits, you get $get after their first session.',
                    style: const TextStyle(fontSize: 12.5, color: AppTokens.onSurfaceVariant)),
                GestureDetector(
                  onTap: _enterCode,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Have a code?',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTokens.primary)),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _share,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Invite', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
