import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../settings/providers/language_provider.dart';
import '../services/gemini_service.dart';
import '../services/audio_playback_service.dart';
import '../../monetization/services/subscription_service.dart';

enum VoiceState { idle, recording, processing, speaking, completed }

class VoiceTherapyNotifier extends Notifier<VoiceState> {
  late final AudioRecorder _audioRecorder;
  Timer? _timer;
  bool _isDisposed = false;
  int durationSeconds = 0;
  
  // API Budgeting: Max audio length for free users to prevent LLM cost spikes
  static const int _maxFreeDurationSeconds = 60;

  String _lastAiTextResponse = "";
  String get lastAiTextResponse => _lastAiTextResponse;
  
  Map<String, dynamic>? _lastSlmFeatures;
  Map<String, dynamic>? get lastSlmFeatures => _lastSlmFeatures;

  String _currentTtsCode = 'en-IN';

  @override
  VoiceState build() {
    _isDisposed = false;
    _audioRecorder = AudioRecorder();

    ref.onDispose(() {
      _isDisposed = true;
      _timer?.cancel();
      _audioRecorder.dispose();
      AudioPlaybackService.instance.stop();
    });

    return VoiceState.idle;
  }

  Future<void> startRecording() async {
    final activeLanguage = ref.read(languageProvider);
    final isPremium = ref.read(subscriptionProvider).isPremium;
    _currentTtsCode = activeLanguage.ttsCode;

    await AudioPlaybackService.instance.stop();

    if (await _audioRecorder.hasPermission()) {
      HapticFeedback.mediumImpact();
      state = VoiceState.recording;
      durationSeconds = 0;

      // 🚨 MARGIN PROTECTION: Hardware-level cutoff timer for non-premium users
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isDisposed) {
          durationSeconds++;
          if (!isPremium && durationSeconds >= _maxFreeDurationSeconds) {
            stopRecordingAndProcess();
            HapticFeedback.heavyImpact();
          }
        }
      });

      final dir = await getApplicationDocumentsDirectory();
      final securePath = '${dir.path}/neurocalm_temp_session.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: securePath,
      );
    }
  }

  Future<void> stopRecordingAndProcess() async {
    if (state != VoiceState.recording) return;

    HapticFeedback.heavyImpact();
    state = VoiceState.processing;
    _timer?.cancel();

    final path = await _audioRecorder.stop();
    if (path == null) {
      state = VoiceState.idle;
      return;
    }

    final activeLanguage = ref.read(languageProvider);
    try {
      final aiData = await GeminiService.instance.generateAudioReply(path, activeLanguage);
      _lastAiTextResponse = aiData['reply'] ?? "I am here for you. Share more when ready.";
      _lastSlmFeatures = aiData['slm_features'];
      state = VoiceState.speaking;

      if (!_isDisposed) {
        final wordCount = _lastAiTextResponse.split(' ').length;
        final estimatedDuration = Duration(milliseconds: (wordCount / 2.5 * 1000).toInt() + 1500);

        Future.delayed(estimatedDuration, () {
          if (!_isDisposed && state == VoiceState.speaking) {
            state = VoiceState.completed;
          }
        });
      }
    } catch (e) {
      _lastAiTextResponse = "It seems we lost connection. I am still here locally.";
      state = VoiceState.completed;
    }
  }

  void reset() {
    AudioPlaybackService.instance.stop();
    state = VoiceState.idle;
    durationSeconds = 0;
    _lastAiTextResponse = "";
    _lastSlmFeatures = null;
    HapticFeedback.selectionClick();
  }
}

final voiceProvider = NotifierProvider<VoiceTherapyNotifier, VoiceState>(() {
  return VoiceTherapyNotifier();
});