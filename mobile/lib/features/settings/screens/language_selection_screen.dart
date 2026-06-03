import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../providers/language_provider.dart'; // 🚨 FIX: Imported the correct unified global provider

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends ConsumerState<LanguageSelectionScreen> {
  late FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setSpeechRate(0.45); // Calm, clear pace for rural users
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  /// AUDIO-FIRST NAVIGATION LOGIC:
  /// Speaks the confirmation in the target dialect so uneducated users know what happened.
  Future<void> _handleLanguageSelect(AppLanguage language) async {
    // 1. Tactile Grounding
    HapticFeedback.heavyImpact();
    
    // 2. Play audio cue for illiterate navigation
    await _tts.setLanguage(language.ttsCode);
    await _tts.speak(language.displayName);

    // 3. Save preference globally to the Riverpod state
    await ref.read(languageProvider.notifier).setLanguage(language);

    // 4. Delayed pop to allow the user to hear the confirmation before the screen closes
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Retrieves the AppLanguage object safely
    final currentLanguage = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Accessibility Branding
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1), 
                  shape: BoxShape.circle
                ),
                child: Icon(Icons.record_voice_over_rounded, size: 40, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Language', 
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w800)
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to hear the language spoken.', 
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600], fontSize: 16)
              ),
              const SizedBox(height: 32),
              
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  // Iterating directly over the global supported languages instead of hardcoded maps
                  itemCount: LanguageNotifier.supportedLanguages.length,
                  // 🚨 FIX: Replaced (_, __) with named parameters to satisfy Dart linter rules
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final dialect = LanguageNotifier.supportedLanguages[index];
                    final isSelected = dialect.code == currentLanguage.code;

                    return InkWell(
                      onTap: () => _handleLanguageSelect(dialect),
                      borderRadius: BorderRadius.circular(24),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : Colors.grey.withValues(alpha: 0.2), 
                            width: 2
                          ),
                          boxShadow: isSelected 
                            ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]
                            : [],
                        ),
                        child: Row(
                          children: [
                            // Visual volume indicator to signal "Audio-First" functionality
                            Icon(
                              Icons.volume_up_rounded, 
                              color: isSelected ? Colors.white : theme.colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Text(
                                dialect.displayName,
                                style: TextStyle(
                                  fontSize: 20, 
                                  fontWeight: FontWeight.w700, 
                                  color: isSelected ? Colors.white : Colors.black87,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (isSelected) 
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}