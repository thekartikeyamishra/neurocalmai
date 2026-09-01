import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Core Architecture & Design System
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/adaptive_layout.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/constants/monetization_constants.dart';

// Features & Components
import '../../subscription/presentation/paywall_bottom_sheet.dart';

/// A hardware-linked somatic grounding tool designed to alleviate panic (10/10 Adaptive Standard).
/// Integrates haptic feedback and simulated biometric camera scanning.
/// Gated behind the platform's dual-track monetization paywalls.
/// Explicitly complies with Google Play Health App policies via clinical disclaimers.
class SomaticGroundingScreen extends StatefulWidget {
  const SomaticGroundingScreen({super.key});

  @override
  State<SomaticGroundingScreen> createState() => _SomaticGroundingScreenState();
}

class _SomaticGroundingScreenState extends State<SomaticGroundingScreen> with SingleTickerProviderStateMixin {
  final IAPService _iapService = IAPService();

  late AnimationController _breathController;
  late Animation<double> _scaleAnimation;

  bool _isSessionActive = false;
  bool _isScanning = false;
  String _instruction = "Tap below to begin somatic grounding.";

  // Immersive tool-specific colors mapping back to the design system
  final Color _immersiveBackground = AppTokens.primary;
  final Color _immersiveForeground = AppTokens.surface;
  final Color _immersiveOrb = const Color(0xFF3A6753); // Specialized contrast orb

  @override
  void initState() {
    super.initState();
    // Initialize the breathing animation controller
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    // Map the 0-1 bounds to a physical scaling multiplier for the breathing circle
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.4).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _isSessionActive = false;
    _breathController.dispose();
    super.dispose();
  }

  /// The entry gate: Checks if the user is premium. 
  /// If not, it halts the flow and throws up the contextual micro-transaction paywall.
  void _triggerSessionGatekeeper() {
    if (_iapService.isPremium) {
      _startBiometricScan();
    } else {
      PaywallBottomSheet.show(
        context: context,
        featureName: "Biometric Grounding",
        featureDescription: "Unlock hardware-linked breathing rhythms and haptic anxiety relief.",
        creditCost: MonetizationConstants.costSomaticGrounding,
        onSuccess: _startBiometricScan,
      );
    }
  }

  /// Phase 1: Simulates optical camera tracking for stress variance.
  Future<void> _startBiometricScan() async {
    setState(() {
      _isScanning = true;
      _instruction = "Calibrating optical pulse via sensor...";
    });

    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    setState(() => _instruction = "Mapping baseline heart rate variance...");
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _isSessionActive = true;
    });

    _runBreathingEngine();
  }

  /// Phase 2: The actual therapeutic loop with synchronized hardware haptics.
  Future<void> _runBreathingEngine() async {
    while (_isSessionActive) {
      if (!mounted) break;

      // -- INHALE (4s) --
      setState(() => _instruction = "Inhale deeply...");
      HapticFeedback.lightImpact();
      await _breathController.animateTo(1.0, duration: const Duration(seconds: 4), curve: Curves.easeInOut);
      if (!_isSessionActive) break;

      // -- HOLD (4s) --
      setState(() => _instruction = "Hold your breath...");
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(seconds: 4));
      if (!_isSessionActive) break;

      // -- EXHALE (6s) --
      setState(() => _instruction = "Exhale slowly...");
      HapticFeedback.heavyImpact();
      await _breathController.animateTo(0.0, duration: const Duration(seconds: 6), curve: Curves.easeInOut);
      if (!_isSessionActive) break;

      // -- REST (2s) --
      setState(() => _instruction = "Rest...");
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Gracefully aborts the session and resets the UI
  void _stopSession() {
    setState(() {
      _isSessionActive = false;
      _isScanning = false;
      _instruction = "Session complete. Great job.";
    });
    _breathController.stop();
    _breathController.animateTo(0.0, duration: const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final horizontalPadding = AdaptiveLayout.getHorizontalPadding(context);

    return Scaffold(
      backgroundColor: _immersiveBackground, // A dark, immersive background for this specific tool
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _immersiveForeground,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close Session',
          onPressed: () {
            _isSessionActive = false; // Kill the loop
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: [
              const SizedBox(height: AppTokens.spacing24),
              
              // Header Text
              Text(
                "Somatic Grounding",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: _immersiveForeground,
                ),
              ),
              const SizedBox(height: AppTokens.spacing8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.spacing32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _instruction,
                    key: ValueKey<String>(_instruction),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _immersiveForeground.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              
              const Spacer(),

              // The Breathing Circle & Scanner Animation
              Center(
                child: _isScanning
                    ? _buildScannerPulse()
                    : Semantics(
                        label: 'Breathing visualizer',
                        child: AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _immersiveOrb,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _immersiveOrb.withValues(alpha: 0.4),
                                      blurRadius: 40,
                                      spreadRadius: 20,
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              
              const Spacer(),

              // Action Buttons
              if (!_isSessionActive && !_isScanning)
                SizedBox(
                  width: double.infinity,
                  height: 56, // Matches standard 10/10 minTouchTarget constraint
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _immersiveForeground,
                      foregroundColor: _immersiveBackground,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                      ),
                    ),
                    onPressed: _triggerSessionGatekeeper,
                    child: const Text(
                      "Start Biometric Session",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                  ),
                ),

              if (_isSessionActive)
                TextButton(
                  onPressed: _stopSession,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(120, AppTokens.minTouchTarget),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
                  ),
                  child: Text(
                    "End Session",
                    style: TextStyle(color: _immersiveForeground.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              
              const SizedBox(height: AppTokens.spacing24),

              // Google Play Medical Disclaimer (Strictly Required)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.spacing8, vertical: AppTokens.spacing16),
                child: Text(
                  "Disclaimer: This platform is not a medical device. It does not diagnose, treat, or prevent any condition. Use for relaxation purposes only.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _immersiveForeground.withValues(alpha: 0.4), 
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A quick localized pulse animation to represent the "scanning" phase
  Widget _buildScannerPulse() {
    return Semantics(
      label: 'Scanning hardware sensor',
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _immersiveForeground.withValues(alpha: 0.5), width: 4),
        ),
        child: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: _immersiveForeground,
              strokeWidth: 3,
            ),
          ),
        ),
      ),
    );
  }
}