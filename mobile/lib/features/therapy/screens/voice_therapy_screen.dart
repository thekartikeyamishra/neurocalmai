import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui'; // Required for ImageFilter/Blur

import '../providers/voice_provider.dart';
import '../../tracking/services/review_service.dart';

class VoiceTherapyScreen extends ConsumerStatefulWidget {
  const VoiceTherapyScreen({super.key});

  @override
  ConsumerState<VoiceTherapyScreen> createState() => _VoiceTherapyScreenState();
}

class _VoiceTherapyScreenState extends ConsumerState<VoiceTherapyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _coreController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  // Premium Therapeutic Palette
  final Color _bgSlate = const Color(0xFF0F172A);
  final Color _aiCyan = const Color(0xFF38BDF8);
  final Color _mutedBlue = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    // 4-second breathing cycle (Inhale 4s / Exhale 4s)
    _coreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _coreController, curve: Curves.easeInOutSine),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _coreController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _coreController.dispose();
    super.dispose();
  }

  void _handleInteraction(VoiceState currentState) async {
    final notifier = ref.read(voiceProvider.notifier);

    if (currentState == VoiceState.idle ||
        currentState == VoiceState.completed) {
      HapticFeedback.heavyImpact(); // Grounding trigger
      _coreController.duration = const Duration(
        milliseconds: 1500,
      ); // Speed up for active state
      _coreController.repeat(reverse: true);
      await notifier.startRecording();
    } else if (currentState == VoiceState.recording) {
      HapticFeedback.mediumImpact();
      _coreController.duration = const Duration(
        milliseconds: 4000,
      ); // Return to calm rhythm
      _coreController.repeat(reverse: true);

      await notifier.stopRecordingAndProcess();

      if (notifier.lastAiTextResponse.isNotEmpty) {
        await AsoReviewService.instance.evaluateSessionForReview(4, 8);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceProvider);
    final notifier = ref.read(voiceProvider.notifier);

    return Scaffold(
      backgroundColor: _bgSlate,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () {
            ref.read(voiceProvider.notifier).reset();
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          // Background Atmospheric Blur
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _aiCyan.withValues(alpha: _glowAnimation.value * 0.3),
                        _bgSlate,
                      ],
                      center: Alignment.center,
                      radius: 1.2,
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  const Spacer(),

                  // Adaptive Messaging System
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1000),
                    child: Text(
                      _getInstructionText(voiceState, notifier),
                      key: ValueKey<VoiceState>(voiceState),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // The AI Core - Multi-layered Animation
                  GestureDetector(
                    onTap: () => _canInteract(voiceState)
                        ? _handleInteraction(voiceState)
                        : null,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Layer 1: Exterior Pulse Ring
                          _buildPulseRing(voiceState),

                          // Layer 2: Core Orb
                          _buildCoreOrb(voiceState),

                          // Layer 3: Glassmorphism Icon Overlay
                          _buildStateIcon(voiceState),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Privacy Security Tag
                  _buildPrivacyBadge(voiceState),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInstructionText(VoiceState state, VoiceTherapyNotifier notifier) {
    switch (state) {
      case VoiceState.idle:
        return "Tap to speak your mind.";
      case VoiceState.recording:
        return "Listening to your thoughts...";
      case VoiceState.processing:
        return "Processing securely...";
      case VoiceState.speaking:
        return notifier.lastAiTextResponse;
      case VoiceState.completed:
        return "Session complete.\nTap to continue.";
    }
  }

  bool _canInteract(VoiceState state) =>
      state != VoiceState.processing && state != VoiceState.speaking;

  Widget _buildPulseRing(VoiceState state) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * 1.2,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: state == VoiceState.recording
                    ? _aiCyan
                    : _mutedBlue.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoreOrb(VoiceState state) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  state == VoiceState.recording ? _aiCyan : Colors.white10,
                  state == VoiceState.recording
                      ? _aiCyan.withValues(alpha: 0.5)
                      : Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (state == VoiceState.recording
                              ? _aiCyan
                              : _aiCyan.withValues(alpha: 0.15))
                          .withValues(alpha: _glowAnimation.value),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStateIcon(VoiceState state) {
    if (state == VoiceState.processing) {
      return const CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 2,
      );
    }

    IconData iconData = Icons.mic_none_rounded;
    if (state == VoiceState.recording) iconData = Icons.stop_rounded;
    if (state == VoiceState.speaking) iconData = Icons.graphic_eq_rounded;
    if (state == VoiceState.completed) iconData = Icons.refresh_rounded;

    return Icon(iconData, color: Colors.white, size: 42);
  }

  Widget _buildPrivacyBadge(VoiceState state) {
    return AnimatedOpacity(
      opacity: (state == VoiceState.idle || state == VoiceState.completed)
          ? 1.0
          : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: _mutedBlue, size: 14),
            const SizedBox(width: 8),
            Text(
              "Zero-Data Architecture. Encrypted locally.",
              style: TextStyle(
                color: _mutedBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
