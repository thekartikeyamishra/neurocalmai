import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart'; // 🚨 NEW IMPORT

class AudioPlaybackService {
  static final AudioPlaybackService instance = AudioPlaybackService._internal();
  final AudioPlayer _audioPlayer = AudioPlayer();

  AudioPlaybackService._internal() {
    // Configure audio context to respect device silent mode (essential for UX)
    _audioPlayer.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        usageType: AndroidUsageType.media,
        contentType: AndroidContentType.speech,
        audioFocus: AndroidAudioFocus.gainTransientExclusive,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback, // Play even if silent switch is on
        options: {AVAudioSessionOptions.duckOthers}, // Use Set {} instead of List []
      ),
    ));
  }

  /// Takes the raw binary array from the Node.js API (or AI response),
  /// saves it securely to a temporary local file, and streams it directly 
  /// to the device speaker to guarantee zero playback stutter.
  Future<void> playAudioBytes(Uint8List audioBytes) async {
    try {
      // 1. Get the secure temporary directory for the device
      final Directory tempDir = await getTemporaryDirectory();
      
      // 2. Define a secure, temporary file path
      // Note: This file gets overwritten every time, preventing storage bloat
      final File file = File('${tempDir.path}/neurocalm_temp_audio.mp3');
      
      // 3. Write the raw bytes to the local file system
      // flush: true ensures the file is completely written before we try to read it
      await file.writeAsBytes(audioBytes, flush: true);
      
      // 4. Play using DeviceFileSource for robust, stutter-free playback
      // Native OS media players handle physical files much better than RAM buffers
      final DeviceFileSource source = DeviceFileSource(file.path);
      await _audioPlayer.play(source);
      
    } catch (e) {
      debugPrint('[AudioPlayback Error]: Failed to decode/play MP3 bytes. $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}