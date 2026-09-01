import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// Core Architecture & Design System
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/adaptive_layout.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/services/secure_ai_gateway.dart';
import '../../../core/constants/monetization_constants.dart';

// Features & Components
import '../../subscription/presentation/paywall_bottom_sheet.dart';
import '../../habit_loop/services/habit_loop_service.dart';
import '../../journal/widgets/cognitive_mirror_card.dart';

/// The Voice-to-Reframe Engine (10/10 Adaptive Standard).
/// Allows users to vent their anxiety verbally. Uses on-device speech-to-text 
/// (for absolute privacy) and routes the transcript through the Secure AI Gateway.
/// Integrates directly with the HabitLoopService for cognitive investment tracking.
class VoiceReframeScreen extends ConsumerStatefulWidget {
  const VoiceReframeScreen({super.key});

  @override
  ConsumerState<VoiceReframeScreen> createState() => _VoiceReframeScreenState();
}

class _VoiceReframeScreenState extends ConsumerState<VoiceReframeScreen> with SingleTickerProviderStateMixin {
  final IAPService _iapService = IAPService();
  final SecureAIGateway _aiGateway = SecureAIGateway();
  final stt.SpeechToText _speech = stt.SpeechToText();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isSpeechInitialized = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _hasInvested = false; // Tracks if the user rated the AI reframe
  
  String _transcribedText = "";
  Map<String, dynamic>? _cbtResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    
    // Pulse animation for the recording button to provide continuous visual feedback
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.cancel();
    super.dispose();
  }

  /// Initializes the on-device speech recognition engine.
  Future<void> _initSpeech() async {
    try {
      _isSpeechInitialized = await _speech.initialize(
        onError: (val) => debugPrint("🚨 [Speech Error]: ${val.errorMsg}"),
        onStatus: (val) {
          if (val == 'done' && _isRecording) {
            _stopRecordingAndProcess();
          }
        },
      );
    } catch (e) {
      debugPrint("🚨 [Speech Init Failed]: $e");
    }
  }

  /// The Monetization Gatekeeper
  void _triggerRecordingGatekeeper() {
    // Clear previous states for a fresh loop
    setState(() {
      _cbtResult = null;
      _errorMessage = null;
      _transcribedText = "";
      _hasInvested = false;
    });

    if (_iapService.isPremium) {
      _startRecording();
    } else {
      PaywallBottomSheet.show(
        context: context,
        featureName: "Advanced Voice Therapy",
        featureDescription: "Vocalize your anxiety and let our AI instantly construct a clinical CBT reframe.",
        creditCost: MonetizationConstants.costVoiceReframe,
        onSuccess: _startRecording,
      );
    }
  }

  /// Begins listening to the user's voice using on-device transcription.
  Future<void> _startRecording() async {
    if (!_isSpeechInitialized) {
      setState(() => _errorMessage = "Microphone permission is required to use this feature.");
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _errorMessage = null;
    });

    await _speech.listen(
      onResult: (val) {
        setState(() {
          _transcribedText = val.recognizedWords;
        });
      },
      cancelOnError: true,
      partialResults: true,
    );
  }

  /// Stops recording and hands the transcript off to the Secure AI Gateway.
  Future<void> _stopRecordingAndProcess() async {
    if (!_isRecording) return;
    
    HapticFeedback.lightImpact();
    await _speech.stop();
    
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    if (_transcribedText.trim().isEmpty) {
      setState(() {
        _isProcessing = false;
        _errorMessage = "We couldn't hear anything. Please try speaking a bit louder.";
      });
      return;
    }

    try {
      final result = await _aiGateway.generateCBTReframe(
        userText: _transcribedText,
        isVoiceTranscribed: true,
      );

      if (mounted) {
        setState(() {
          _cbtResult = result;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceAll("Exception: ", "");
        });
      }
    }
  }

  /// Habit Loop Integration: Registers the user's evaluation of the AI output.
  Future<void> _submitInvestment(bool isHelpful) async {
    if (_hasInvested) return;
    setState(() => _hasInvested = true);

    await ref.read(habitLoopServiceProvider).commitCognitiveInvestment(
      cognitiveDistortion: _cbtResult?['distortion']?.toString() ?? 'Unclassified',
      successfulReframingPattern: _cbtResult?['reframe']?.toString() ?? 'Unknown',
      userHelpfulnessRating: isHelpful,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isHelpful ? Icons.check_circle_rounded : Icons.sync_rounded, color: Colors.white),
              const SizedBox(width: AppTokens.spacing12),
              Expanded(
                child: Text(
                  isHelpful ? 'Neural pathway reinforced.' : 'Bias registered for recalibration.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: isHelpful ? AppTokens.success : AppTokens.onSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final horizontalPadding = AdaptiveLayout.getHorizontalPadding(context);

    return Scaffold(
      backgroundColor: AppTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTokens.primary,
        centerTitle: true,
        title: const Text(
          "Voice Reframe",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: AppTokens.spacing24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dynamic Header based on State
                    _buildHeader(theme),
                    const SizedBox(height: AppTokens.spacing32),

                    // Error Message Display
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(AppTokens.spacing16),
                        decoration: BoxDecoration(
                          color: AppTokens.errorContainer,
                          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                          border: Border.all(color: AppTokens.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTokens.error, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Live Transcription View
                    if (_transcribedText.isNotEmpty && _cbtResult == null && !_isProcessing)
                      Container(
                        padding: const EdgeInsets.all(AppTokens.spacing24),
                        decoration: BoxDecoration(
                          color: AppTokens.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                          border: Border.all(color: AppTokens.onSurfaceVariant.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Text(
                          _transcribedText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppTokens.onSurfaceVariant,
                          ),
                        ),
                      ),

                    // Processing Indicator
                    if (_isProcessing)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppTokens.spacing48),
                        child: Center(
                          child: CircularProgressIndicator(color: AppTokens.primary, strokeWidth: 3),
                        ),
                      ),

                    // CBT Result Display (Variable Reward)
                    if (_cbtResult != null) _buildCbtResultView(theme),
                  ],
                ),
              ),
            ),
            
            // Fixed Bottom Action Area (The Microphone)
            _buildMicrophoneController(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    if (_cbtResult != null) {
      return Text(
        "Your Reframe",
        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: AppTokens.primary),
        textAlign: TextAlign.center,
      );
    }
    
    if (_isRecording) {
      return Text(
        "Listening safely...",
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTokens.secondary),
        textAlign: TextAlign.center,
      );
    }
    
    return Column(
      children: [
        Text(
          "Let it out.",
          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: AppTokens.primary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTokens.spacing8),
        Text(
          "Speak your anxious thoughts out loud.\nWe process your voice locally for absolute privacy.",
          style: theme.textTheme.bodyMedium?.copyWith(color: AppTokens.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCbtResultView(ThemeData theme) {
    final distortion = _cbtResult?['distortion'] ?? 'Unclassified Pattern';
    final reframe = _cbtResult?['reframe'] ?? 'Unable to process reframe text.';
    final action = _cbtResult?['action'] ?? 'Take a deep breath and center yourself.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Premium Cognitive Mirror Card (Variable Reward)
        CognitiveMirrorCard(
          rawDistortion: distortion,
          socraticQuestion: reframe,
        ),
        const SizedBox(height: AppTokens.spacing16),

        // Actionable Next Step
        Container(
          padding: const EdgeInsets.all(AppTokens.spacing24),
          decoration: BoxDecoration(
            color: AppTokens.primaryContainer,
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.arrow_forward_rounded, color: AppTokens.primary, size: 20),
              const SizedBox(width: AppTokens.spacing12),
              Expanded(
                child: Text(
                  action,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppTokens.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spacing32),

        // The Investment Phase (Hooked Model)
        AnimatedOpacity(
          opacity: _hasInvested ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Column(
            children: [
              Text(
                "Did this reframe interrupt your thought loop?",
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(color: AppTokens.onSurfaceVariant),
              ),
              const SizedBox(height: AppTokens.spacing16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _hasInvested ? null : () => _submitInvestment(false),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text("Not Really"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTokens.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: AppTokens.spacing16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spacing16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _hasInvested ? null : () => _submitInvestment(true),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text("Helpful"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: AppTokens.spacing16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMicrophoneController(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spacing24, horizontal: AppTokens.spacing24),
      decoration: BoxDecoration(
        color: AppTokens.surfaceContainer,
        border: Border(top: BorderSide(color: AppTokens.onSurfaceVariant.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: _isRecording ? "Stop recording" : "Start recording",
              child: _isRecording
                  ? AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: FloatingActionButton(
                            onPressed: _stopRecordingAndProcess,
                            backgroundColor: AppTokens.error,
                            elevation: 8,
                            child: const Icon(Icons.stop_rounded, size: 32, color: Colors.white),
                          ),
                        );
                      },
                    )
                  : FloatingActionButton(
                      onPressed: _isProcessing ? null : _triggerRecordingGatekeeper,
                      backgroundColor: _isProcessing ? AppTokens.onSurfaceVariant.withValues(alpha: 0.5) : AppTokens.primary,
                      elevation: 4,
                      child: const Icon(Icons.mic_none_rounded, size: 32, color: Colors.white),
                    ),
            ),
            
            const SizedBox(height: AppTokens.spacing16),
            
            if (!_isRecording && !_isProcessing)
              Text(
                _cbtResult != null ? "Tap to reframe another thought" : "Tap to speak",
                style: theme.textTheme.labelMedium?.copyWith(color: AppTokens.onSurfaceVariant, fontWeight: FontWeight.w600),
              )
            else if (_isRecording)
              Text(
                "Tap to analyze",
                style: theme.textTheme.labelMedium?.copyWith(color: AppTokens.error, fontWeight: FontWeight.w700),
              )
          ],
        ),
      ),
    );
  }
}