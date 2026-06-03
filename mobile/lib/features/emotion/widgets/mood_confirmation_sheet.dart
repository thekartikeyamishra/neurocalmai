import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Internal Providers & Services
import '../providers/emotion_provider.dart';

// 🚨 UPDATE: Import your new Aura / Intervention Screen here.
// Adjust this path if your AuraScreen is located in a different feature folder.
import '../../aura/screens/aura_screen.dart'; 

class MoodConfirmationSheet extends ConsumerStatefulWidget {
  const MoodConfirmationSheet({super.key});

  @override
  ConsumerState<MoodConfirmationSheet> createState() => _MoodConfirmationSheetState();
}

class _MoodConfirmationSheetState extends ConsumerState<MoodConfirmationSheet> {
  double _currentMoodValue = 5; // Default middle
  bool _isAdjusted = false;

  @override
  void initState() {
    super.initState();
    // Initialize slider with the AI's detected value
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final detectedData = ref.read(emotionProvider.notifier).lastDetectedEmotion;
      if (detectedData != null && mounted) {
        setState(() {
          _currentMoodValue = detectedData.moodScore.toDouble();
        });
      }
    });
  }

  /// Maps the numeric score back to a context string for the Aura AI Prompt
  String _getMoodLabel(double value) {
    if (value <= 3) return "Stressed / Distressed";
    if (value <= 6) return "Neutral / Anxious";
    return "Calm & Positive";
  }

  void _confirmMood() {
    // Premium heavy haptic feedback for a decisive action
    HapticFeedback.heavyImpact(); 
    
    // 🚨 DATA COLLECTION PURGED: We no longer save session logs to SQLite.
    // The mood is acknowledged purely for the user's immediate cognitive grounding.
    debugPrint('[Emotion Intelligence]: Final confirmed mood score $_currentMoodValue registered securely in-memory.');
    
    final String finalMood = _getMoodLabel(_currentMoodValue);

    if (mounted) {
      // 1. Pop the BottomSheet
      Navigator.pop(context); 
      
      // 2. Navigate smoothly to the Organic Viral Factor "Aura Screen"
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) {
            return AuraScreen(
              primaryEmotion: finalMood,
              moodScore: _currentMoodValue.toInt(),
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Fluid, calming fade transition into the Aura Screen
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detectedData = ref.read(emotionProvider.notifier).lastDetectedEmotion;
    final theme = Theme.of(context);

    if (detectedData == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Does this feel accurate?',
            style: theme.textTheme.displayLarge?.copyWith(fontSize: 24, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 12),
          // Ignore cSpell warning for the brand name "NeuroCalm"
          Text(
            'NeuroCalm detected you might be feeling ${_isAdjusted ? "a bit different" : detectedData.primaryEmotion}. Adjust the slider to match your actual state.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600], fontSize: 15),
          ),
          const SizedBox(height: 40),
          
          // Mood Score Readout
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Text(
              _currentMoodValue.toInt().toString(),
              key: ValueKey<int>(_currentMoodValue.toInt()),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: _getMoodColor(_currentMoodValue),
              ),
            ),
          ),
          Text(
            '1 = Distressed, 10 = Calm',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 24),
          
          // Adjustment Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _getMoodColor(_currentMoodValue),
              inactiveTrackColor: Colors.grey[200],
              thumbColor: _getMoodColor(_currentMoodValue),
              trackHeight: 8,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14.0),
            ),
            child: Slider(
              value: _currentMoodValue,
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (value) {
                // Subtle haptic tick for each slider division
                HapticFeedback.selectionClick();
                setState(() {
                  _currentMoodValue = value;
                  _isAdjusted = true;
                });
              },
            ),
          ),
          const SizedBox(height: 40),
          
          // E-004 Mandatory Confirmation Action
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _confirmMood,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Confirm & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMoodColor(double value) {
    if (value <= 3) return Colors.deepOrange; // High distress
    if (value <= 6) return const Color(0xFFE6A822); // Neutral/Anxious
    return const Color(0xFF2A5C5A); // Calm (Primary App Color)
  }
}