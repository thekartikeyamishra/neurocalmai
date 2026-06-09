import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../settings/providers/language_provider.dart';
import '../services/gemini_service.dart'; 
import '../services/audio_playback_service.dart';

enum VoiceState { idle, recording, processing, speaking, completed }

class VoiceTherapyNotifier extends Notifier<VoiceState> {
  late final AudioRecorder _audioRecorder;
  Timer? _timer;
  
  bool _isDisposed = false; 
  int durationSeconds = 0;

  // AI Response Data
  String _lastAiTextResponse = "";
  String get lastAiTextResponse => _lastAiTextResponse;

  // Monetization Hook
  Map<String, dynamic>? _lastSlmFeatures;
  Map<String, dynamic>? get lastSlmFeatures => _lastSlmFeatures;

  // Tracks the active BCP-47 OS code for localized fallback error strings
  String _currentTtsCode = 'en-IN';

  @override
  VoiceState build() {
    _isDisposed = false;
    _audioRecorder = AudioRecorder();
    
    // Prevent native memory leaks when the provider is destroyed
    ref.onDispose(() {
      _isDisposed = true;
      _timer?.cancel();
      _audioRecorder.dispose();
      AudioPlaybackService.instance.stop(); // Stop audio if user exits mid-sentence
    });
    
    return VoiceState.idle;
  }

  /// 1. Hardware Capture: Request mic permission and start recording
  Future<void> startRecording() async {
    final activeLanguage = ref.read(languageProvider);
    _currentTtsCode = activeLanguage.ttsCode;

    // Ensure any previous audio is killed before starting a new session
    await AudioPlaybackService.instance.stop();

    if (await _audioRecorder.hasPermission()) {
      HapticFeedback.mediumImpact(); 
      state = VoiceState.recording;
      durationSeconds = 0;
      
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isDisposed) durationSeconds++;
      });

      final dir = await getApplicationDocumentsDirectory();
      // cSpell:disable-next-line
      final securePath = '${dir.path}/neurocalm_temp_session.m4a';

      // AAC format compresses the file to save bandwidth for rural users
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc), 
        path: securePath,
      );
    } else {
      debugPrint('[Hardware Security]: Microphone permission denied by user.');
    }
  }

  /// 2. Secure Cloud Processing: 100% Gemini Flash Multimodal Pipeline
  Future<void> stopRecordingAndProcess() async {
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
      // 🚨 100% GEMINI PIPELINE: Direct Audio-to-JSON Multimodal Processing
      // Bypasses Whisper and GPT completely, dropping cost to near zero.
      final aiData = await GeminiService.instance.generateAudioReply(
        path, 
        activeLanguage
      );

      _lastAiTextResponse = aiData['reply'] ?? _getLocalizedFallback();
      _lastSlmFeatures = aiData['slm_features'];

      // Show the text immediately on the UI
      state = VoiceState.speaking;

      // 🚨 TTS Note: Since paid cloud TTS was removed to maximize margins, 
      // we simulate the duration of the reading so the UI flows naturally.
      // (Integration with the 100% free `flutter_tts` local package is recommended).
      if (!_isDisposed) {
        final wordCount = _lastAiTextResponse.split(' ').length;
        // Average speaking rate: ~2.5 words per second + 1.5s natural buffer
        final estimatedDuration = Duration(milliseconds: (wordCount / 2.5 * 1000).toInt() + 1500);
        
        Future.delayed(estimatedDuration, () {
          if (!_isDisposed && state == VoiceState.speaking) {
            state = VoiceState.completed;
          }
        });
      }

    } catch (e) {
      debugPrint('[Voice Pipeline Error]: $e');
      
      // Graceful error handling for network issues
      if (e.toString().contains("network") || e.toString().contains("timeout") || e.toString().contains("SocketException")) {
        _lastAiTextResponse = _getLocalizedOfflineMessage();
      } else {
        _lastAiTextResponse = _getLocalizedError();
      }
      
      // Bypass speaking simulation on error so the user can read the fallback immediately
      state = VoiceState.completed; 
    }
  }

  // --- Localized Fallback Strings for Illiterate/Rural Users ---
  // cSpell:disable
  String _getLocalizedFallback() {
    if (_currentTtsCode == 'hi-IN') return "मैं यहाँ हूँ। क्या आप कुछ और बता सकते हैं?";
    if (_currentTtsCode == 'ta-IN') return "நான் உங்களுக்காக இங்கே இருக்கிறேன். மேலும் கொஞ்சம் பகிர முடியுமா?";
    if (_currentTtsCode == 'mr-IN') return "मी इथे आहे. तुम्ही आणखी काही सांगू शकता का?";
    if (_currentTtsCode == 'bn-IN') return "আমি আপনার জন্য এখানে আছি। আপনি কি আরও কিছু শেয়ার করতে পারেন?";
    if (_currentTtsCode == 'te-IN') return "నేను మీ కోసం ఇక్కడ ఉన్నాను. మీరు మరికొంత పంచుకోగలరా?";
    return "I am here for you. Could you share a bit more?";
  }

  String _getLocalizedOfflineMessage() {
    if (_currentTtsCode == 'hi-IN') return "लगता है इंटरनेट नहीं है। लंबी सांस लें, मैं यहीं हूँ।";
    if (_currentTtsCode == 'ta-IN') return "இணையம் இல்லை என்று தெரிகிறது. ஆழமாக மூச்சு விடுங்கள். நான் இங்கேயே இருக்கிறேன்.";
    if (_currentTtsCode == 'mr-IN') return "इंटरनेट नाही असे दिसते. दीर्घ श्वास घ्या. मी इथेच आहे.";
    if (_currentTtsCode == 'bn-IN') return "মনে হচ্ছে সংযোগ বিচ্ছিন্ন হয়ে গেছে। একটি গভীর শ্বাস নিন। আমি এখনও স্থানীয়ভাবে এখানে আছি।";
    if (_currentTtsCode == 'te-IN') return "కనెక్షన్ పోయినట్లుంది. దీర్ఘంగా గాలి పీల్చుకోండి. నేను ఇక్కడే ఉన్నాను.";
    return "It seems we lost connection. Take a deep breath. I am still here locally.";
  }

  String _getLocalizedError() {
    if (_currentTtsCode == 'hi-IN') return "कुछ गड़बड़ हो गई। कृपया फिर से बोलें।";
    if (_currentTtsCode == 'ta-IN') return "ஒரு பிழை ஏற்பட்டுள்ளது. தயவுசெய்து மீண்டும் பேசவும்.";
    if (_currentTtsCode == 'mr-IN') return "काहीतरी चूक झाली. कृपया पुन्हा बोला.";
    if (_currentTtsCode == 'bn-IN') return "একটি ত্রুটি ঘটেছে। আবার কথা বলার চেষ্টা করুন।";
    if (_currentTtsCode == 'te-IN') return "ఒక లోపం ఏర్పడింది. దయచేసి మళ్ళీ మాట్లాడండి.";
    return "An error occurred. Please try speaking again.";
  }
  // cSpell:enable
  
  /// Reset the provider to allow for continuous conversation
  void reset() {
    AudioPlaybackService.instance.stop(); // Ensure audio stops if they hit reset
    state = VoiceState.idle;
    durationSeconds = 0;
    _lastAiTextResponse = "";
    _lastSlmFeatures = null; // Clear monetization hook for the next session
    HapticFeedback.selectionClick();
  }
}

// Riverpod Global Provider
final voiceProvider = NotifierProvider<VoiceTherapyNotifier, VoiceState>(() {
  return VoiceTherapyNotifier();
});