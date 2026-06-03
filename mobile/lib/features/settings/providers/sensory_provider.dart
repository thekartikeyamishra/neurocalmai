import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's sensory preferences (Haptics & Voice Guidance)
class SensoryState {
  final bool hapticsEnabled;
  final bool voiceGuidanceEnabled;

  const SensoryState({
    this.hapticsEnabled = true,
    this.voiceGuidanceEnabled = false,
  });

  SensoryState copyWith({bool? hapticsEnabled, bool? voiceGuidanceEnabled}) {
    return SensoryState(
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      voiceGuidanceEnabled: voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
    );
  }
}

/// Manages sensory settings and persists them to local device storage
class SensoryNotifier extends Notifier<SensoryState> {
  SharedPreferences? _prefs;

  @override
  SensoryState build() {
    // Trigger async load, but return initial default state synchronously
    _loadPrefs();
    return const SensoryState(
      hapticsEnabled: true,
      voiceGuidanceEnabled: false,
    );
  }

  /// Loads preferences from device storage
  Future<void> _loadPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      final haptics = _prefs?.getBool('haptics_enabled') ?? true;
      final voice = _prefs?.getBool('voice_guidance_enabled') ?? false;

      state = SensoryState(
        hapticsEnabled: haptics,
        voiceGuidanceEnabled: voice,
      );
    } catch (e) {
      debugPrint('[SensoryProvider Error]: Failed to load preferences - $e');
    }
  }

  /// Toggles haptic feedback (physical grounding) on or off
  Future<void> toggleHaptics(bool value) async {
    state = state.copyWith(hapticsEnabled: value);

    try {
      // Ensure prefs instance exists before writing, in case user taps immediately on load
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool('haptics_enabled', value);
    } catch (e) {
      debugPrint('[SensoryProvider Error]: Failed to save haptics state - $e');
    }
  }

  /// Toggles voice guidance (TTS) on or off for eyes-closed usage
  Future<void> toggleVoiceGuidance(bool value) async {
    state = state.copyWith(voiceGuidanceEnabled: value);

    try {
      // Ensure prefs instance exists before writing
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool('voice_guidance_enabled', value);
    } catch (e) {
      debugPrint(
        '[SensoryProvider Error]: Failed to save voice guidance state - $e',
      );
    }
  }
}

/// Global Riverpod Provider for Sensory Settings
final sensoryProvider = NotifierProvider<SensoryNotifier, SensoryState>(() {
  return SensoryNotifier();
});
