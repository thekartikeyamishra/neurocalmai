import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../settings/providers/sensory_provider.dart';
import '../../settings/providers/language_provider.dart'; 

class BreathingScreen extends ConsumerStatefulWidget {
  const BreathingScreen({super.key});

  @override
  ConsumerState<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends ConsumerState<BreathingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late FlutterTts _tts;

  String _instructionText = "Ready?";
  bool _isBreathing = false;
  bool _isCycleActive = false; // 🚨 GUARD: Prevents overlapping async loops

  // 4-7-8 Parasympathetic Breathing timings (ms)
  final int inhaleDuration = 4000;
  final int holdDuration = 7000;
  final int exhaleDuration = 8000;

  // OFFLINE DIALECT DICTIONARY
  // cSpell:disable
  final Map<String, Map<String, String>> _localL10n = {
    'en-IN': {
      'inhale': 'Breathe In...',
      'hold': 'Hold...',
      'exhale': 'Breathe Out...',
      'ready': 'Ready?',
    },
    'hi-IN': {
      'inhale': 'सांस अंदर लें...',
      'hold': 'रोक कर रखें...',
      'exhale': 'सांस बाहर छोड़ें...',
      'ready': 'तैयार?',
    },
    'ta-IN': {
      'inhale': 'மூச்சை உள்ளிழுக்கவும்...',
      'hold': 'மூச்சை அடக்கவும்...',
      'exhale': 'மூச்சை வெளிவிடவும்...',
      'ready': 'தயாரா?',
    },
    'mr-IN': {
      'inhale': 'श्वास आत घ्या...',
      'hold': 'श्वास रोखून धरा...',
      'exhale': 'श्वास बाहेर सोडा...',
      'ready': 'तयार आहात?',
    },
    'bn-IN': {
      'inhale': 'শ্বাস নিন...',
      'hold': 'ধরে রাখুন...',
      'exhale': 'শ্বাস ছাড়ুন...',
      'ready': 'প্রস্তুত?',
    },
    'te-IN': {
      'inhale': 'గాలి పీల్చండి...',
      'hold': 'ఆపండి...',
      'exhale': 'గాలి వదలండి...',
      'ready': 'సిద్ధమా?',
    },
  };
  // cSpell:enable

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 1), // Base duration, overridden by animateTo
    );
    
    // Core scaling factor
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _tts = FlutterTts();
    _tts.setSpeechRate(0.4); 
    _tts.setPitch(0.9);
  }

  void _triggerHaptic(bool isHeavy) {
    if (ref.read(sensoryProvider).hapticsEnabled) {
      isHeavy ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    }
  }

  Future<void> _speakGuidance(String key, AppLanguage dialect) async {
    if (ref.read(sensoryProvider).voiceGuidanceEnabled && _isBreathing) {
      final text = _localL10n[dialect.code]?[key] ?? _localL10n['en-IN']![key]!;
      await _tts.setLanguage(dialect.ttsCode);
      await _tts.speak(text);
    }
  }

  void _toggleBreathing() {
    if (_isBreathing) {
      _stopBreathingCycle();
    } else {
      _startBreathingCycle();
    }
  }

  void _stopBreathingCycle() {
    _triggerHaptic(true);
    _tts.stop();
    final activeDialect = ref.read(languageProvider);

    setState(() {
      _isBreathing = false;
      _instructionText = _localL10n[activeDialect.code]?['ready'] ?? "Ready?";
    });
    
    // 🚨 ARCHITECT FIX: Safely gracefully reset animation
    _controller.animateTo(
      0.0,
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
    );
  }

  void _startBreathingCycle() async {
    if (_isCycleActive) return; // Prevent spam-tap concurrency
    
    _triggerHaptic(false);
    setState(() {
      _isBreathing = true;
      _isCycleActive = true;
    });

    while (_isBreathing && mounted) {
      final activeDialect = ref.read(languageProvider);

      // --- 1. Inhale Phase (Expand) ---
      setState(() => _instructionText = _localL10n[activeDialect.code]?['inhale'] ?? "Breathe In...");
      _triggerHaptic(false);
      _speakGuidance('inhale', activeDialect);

      // Safely animate from 0.0 to 1.0 without mutating the controller's base properties
      await _controller.animateTo(1.0, duration: Duration(milliseconds: inhaleDuration), curve: Curves.easeInOutSine);
      if (!_isBreathing || !mounted) break;

      // --- 2. Hold Phase (Static) ---
      setState(() => _instructionText = _localL10n[activeDialect.code]?['hold'] ?? "Hold...");
      _triggerHaptic(true);
      _speakGuidance('hold', activeDialect);

      int holdTimePassed = 0;
      while (holdTimePassed < holdDuration && _isBreathing && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        holdTimePassed += 100;
      }
      if (!_isBreathing || !mounted) break;

      // --- 3. Exhale Phase (Contract) ---
      setState(() => _instructionText = _localL10n[activeDialect.code]?['exhale'] ?? "Breathe Out...");
      _triggerHaptic(false);
      _speakGuidance('exhale', activeDialect);

      await _controller.animateTo(0.0, duration: Duration(milliseconds: exhaleDuration), curve: Curves.easeInOutSine);
      if (!_isBreathing || !mounted) break;

      _triggerHaptic(true); // Cycle completion tactile cue
    }
    
    _isCycleActive = false; // Release lock
  }

  @override
  void dispose() {
    _isBreathing = false;
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeDialect = ref.watch(languageProvider);

    // Updates localization immediately if user returns from settings
    if (!_isBreathing) {
      _instructionText = _localL10n[activeDialect.code]?['ready'] ?? "Ready?";
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            _isBreathing = false;
            _tts.stop();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Panic Mode',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 28,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Follow the circle. You are safe.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const Spacer(),

              // 🚨 ARCHITECT FIX: Multi-layered Premium Glowing Aura
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer faint glow
                      Transform.scale(
                        scale: _scaleAnimation.value * 1.15,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      // Inner intense aura
                      Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.15 * _scaleAnimation.value),
                                blurRadius: 40 * _scaleAnimation.value,
                                spreadRadius: 10 * _scaleAnimation.value,
                              ),
                            ],
                          ),
                          child: Center(
                            // 🚨 ARCHITECT FIX: Fluid cross-fading text replaces jarring instantaneous swaps
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 600),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              child: Text(
                                _instructionText,
                                key: ValueKey<String>(_instructionText),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displayLarge?.copyWith(
                                  // Prevents text from stretching bizarrely when the circle scales
                                  fontSize: 22, 
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const Spacer(),

              // Dynamic CTA Button
              SizedBox(
                height: 56,
                width: 220,
                child: ElevatedButton.icon(
                  onPressed: _toggleBreathing,
                  icon: Icon(
                    _isBreathing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: _isBreathing ? Colors.redAccent : Colors.white,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isBreathing
                        ? Colors.redAccent.withValues(alpha: 0.1)
                        : theme.colorScheme.primary,
                    foregroundColor: _isBreathing ? Colors.redAccent : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                    side: _isBreathing
                        ? BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                            width: 1.5,
                          )
                        : BorderSide.none,
                  ),
                  label: Text(
                    _isBreathing ? 'Stop Exercise' : 'Start Exercise',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}