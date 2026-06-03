import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum EmotionScanState { idle, scanning, processing, completed, error }

class EmotionData {
  final int moodScore; // 1-10
  final String primaryEmotion;

  EmotionData({required this.moodScore, required this.primaryEmotion});
}

class EmotionNotifier extends Notifier<EmotionScanState> {
  EmotionData? _lastDetectedEmotion;
  EmotionData? get lastDetectedEmotion => _lastDetectedEmotion;

  // ML Kit Face Detector instance
  late final FaceDetector _faceDetector;

  @override
  EmotionScanState build() {
    // 1. Initialize ML Kit for local, on-device face classification
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // Needed for smile/eye-open probability
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    // 2. Production Riverpod Cleanup (Prevents Native Memory Leaks)
    ref.onDispose(() {
      _faceDetector.close(); // Clean up native ML Kit memory when provider dies
    });

    return EmotionScanState.idle;
  }

  /// Processes an image frame completely on-device.
  /// Security Protocol E-003: No network calls are made. No images are saved.
  Future<void> processImageFrame(InputImage inputImage) async {
    // Prevent overlapping processing calls
    if (state == EmotionScanState.processing) return;
    
    state = EmotionScanState.processing;

    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        state = EmotionScanState.error;
        return;
      }

      // Analyze the primary face in the frame
      final face = faces.first;
      
      // Extract smile probability (0.0 to 1.0)
      double smileProb = face.smilingProbability ?? 0.0;
      
      // Map biological probability (0.0 - 1.0) to Psychological Mood Score (1-10)
      int calculatedMood = (smileProb * 10).round().clamp(1, 10);
      String emotionText = _deriveEmotionText(calculatedMood);

      _lastDetectedEmotion = EmotionData(
        moodScore: calculatedMood,
        primaryEmotion: emotionText,
      );

      state = EmotionScanState.completed;

    } catch (e) {
      debugPrint('[Emotion ML Error]: $e');
      state = EmotionScanState.error;
    }
  }

  /// Psychological Mapping
  String _deriveEmotionText(int score) {
    if (score >= 8) return 'Calm / Happy';
    if (score >= 5) return 'Neutral';
    if (score >= 3) return 'Anxious / Tense';
    return 'Distressed';
  }

  /// Resets the scanner state to allow for a new scan
  void reset() {
    state = EmotionScanState.idle;
    _lastDetectedEmotion = null;
  }
}

// Global Provider
final emotionProvider = NotifierProvider<EmotionNotifier, EmotionScanState>(() {
  return EmotionNotifier();
});