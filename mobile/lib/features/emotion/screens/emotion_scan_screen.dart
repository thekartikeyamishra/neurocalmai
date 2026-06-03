import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../providers/emotion_provider.dart';
import '../widgets/mood_confirmation_sheet.dart';

class EmotionScanScreen extends ConsumerStatefulWidget {
  const EmotionScanScreen({super.key});

  @override
  ConsumerState<EmotionScanScreen> createState() => _EmotionScanScreenState();
}

class _EmotionScanScreenState extends ConsumerState<EmotionScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// 1. Hardware Integration: Opens front camera, captures frame, and sends to ML Kit
  void _handleScanTrigger(EmotionScanState scanState) async {
    if (scanState == EmotionScanState.idle) {
      HapticFeedback.mediumImpact();
      _pulseController.repeat(reverse: true);
      
      try {
        // Launch native camera (Front-facing preferred for facial analysis)
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
        );

        if (image != null) {
          // Convert to ML Kit format and process on-device
          final inputImage = InputImage.fromFilePath(image.path);
          await ref.read(emotionProvider.notifier).processImageFrame(inputImage);

          // Trigger mandatory user confirmation (E-004) if scan was successful
          if (mounted && ref.read(emotionProvider) == EmotionScanState.completed) {
            _showConfirmationSheet();
          }
        } else {
          // User aborted the camera
          ref.read(emotionProvider.notifier).reset();
        }
      } catch (e) {
        debugPrint('[Camera Error]: Failed to capture image. $e');
        ref.read(emotionProvider.notifier).reset();
      }

      // Stop animations and provide tactile completion feedback
      _pulseController.stop();
      _pulseController.reset();
      HapticFeedback.heavyImpact();
    }
  }

  void _showConfirmationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => const MoodConfirmationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(emotionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface, // Updated from deprecated background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            ref.read(emotionProvider.notifier).reset();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'Emotion Sync',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 28, 
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Allow NeuroCalm to read your micro-expressions and tone to better calibrate your therapy.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600], height: 1.5),
              ),
              const Spacer(),
              
              // Animated Scanner UI
              GestureDetector(
                onTap: () => scanState == EmotionScanState.idle ? _handleScanTrigger(scanState) : null,
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    height: 160,
                    width: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scanState == EmotionScanState.scanning 
                          ? theme.colorScheme.primary.withValues(alpha: 0.1) // Updated from withOpacity
                          : theme.colorScheme.surface,
                      border: Border.all(
                        color: scanState == EmotionScanState.scanning 
                            ? theme.colorScheme.primary 
                            : Colors.grey.withValues(alpha: 0.3), // Updated from withOpacity
                        width: scanState == EmotionScanState.scanning ? 3 : 1,
                      ),
                      boxShadow: [
                        if (scanState == EmotionScanState.idle)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05), // Updated from withOpacity
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                      ],
                    ),
                    child: Center(
                      child: _buildScannerCenter(scanState, theme),
                    ),
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Strict Privacy Disclaimer (E-003)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05), // Updated from withOpacity
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_rounded, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '100% On-Device. No images are ever saved, stored, or uploaded to our servers.',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.w500, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerCenter(EmotionScanState state, ThemeData theme) {
    switch (state) {
      case EmotionScanState.scanning:
      case EmotionScanState.processing:
        return const CircularProgressIndicator();
      case EmotionScanState.completed:
        return Icon(Icons.check_rounded, size: 64, color: theme.colorScheme.primary);
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.face_retouching_natural_rounded, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'Tap to Scan',
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        );
    }
  }
}