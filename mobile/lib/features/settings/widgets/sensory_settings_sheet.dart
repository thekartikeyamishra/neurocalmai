import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sensory_provider.dart';

class SensorySettingsSheet extends ConsumerWidget {
  const SensorySettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensoryState = ref.watch(sensoryProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4, width: 40,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Icon(Icons.accessibility_new_rounded, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Text('Sensory Preferences', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 24),
          
          SwitchListTile.adaptive(
            title: const Text('Voice Guidance', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Read instructions aloud for eyes-closed use.'),
            activeThumbColor: theme.colorScheme.primary,
            value: sensoryState.voiceGuidanceEnabled,
            onChanged: (val) {
              if (sensoryState.hapticsEnabled) HapticFeedback.lightImpact();
              ref.read(sensoryProvider.notifier).toggleVoiceGuidance(val);
            },
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: const Text('Haptic Grounding', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Physical vibrations during breathing exercises.'),
            activeThumbColor: theme.colorScheme.primary,
            value: sensoryState.hapticsEnabled,
            onChanged: (val) {
              if (val) HapticFeedback.lightImpact();
              ref.read(sensoryProvider.notifier).toggleHaptics(val);
            },
          ),
        ],
      ),
    );
  }
}