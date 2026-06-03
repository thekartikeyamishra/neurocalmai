import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ShareService {
  final ScreenshotController screenshotController = ScreenshotController();

  Future<void> shareAura(BuildContext context, Widget auraCard) async {
    try {
      HapticFeedback.lightImpact();
      
      final imageBytes = await screenshotController.captureFromWidget(
        Material(
          color: const Color(0xFFF7F9F9), // Match App Theme
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                auraCard,
                const SizedBox(height: 24),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.spa_rounded, color: Color(0xFF2A5C5A), size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Find your center with NeuroCalm",
                      style: TextStyle(color: Color(0xFF2A5C5A), fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        delay: const Duration(milliseconds: 100),
      );

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/my_aura.png').create();
      await imagePath.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Just checked my emotional baseline. #NeuroCalm #MentalWellness',
      );
      
      HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint("[ShareService Error]: $e");
    }
  }
}