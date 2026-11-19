import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../navigation/app_navigator.dart';
import '../theme/app_tokens.dart';
import '../utils/region_detector.dart';

/// Safety net shown whenever the server (or local check) flags possible
/// self-harm risk. A wellness app without this is a legal and moral liability
/// and a common reason for store removal.
class CrisisSupport {
  CrisisSupport._();
  static DateTime? _lastShown;

  static List<_Line> _linesFor(String country) {
    switch (country) {
      case 'IN':
        return const [
          _Line('Tele-MANAS (Govt. of India, 24×7, free)', '14416'),
          _Line('Tele-MANAS alternate', '18008914416'),
          _Line('Emergency', '112'),
        ];
      case 'US':
      case 'CA':
        return const [_Line('988 Suicide & Crisis Lifeline', '988'), _Line('Emergency', '911')];
      case 'GB':
      case 'IE':
        return const [_Line('Samaritans (24/7, free)', '116123'), _Line('Emergency', '999')];
      default:
        return const [_Line('Emergency services', '112')];
    }
  }

  /// Shows the sheet at most once per 10 minutes (avoids stacking).
  static Future<void> show({BuildContext? context}) async {
    final now = DateTime.now();
    if (_lastShown != null && now.difference(_lastShown!).inMinutes < 10) return;
    _lastShown = now;
    final ctx = context ?? appNavigatorKey.currentContext;
    if (ctx == null) return;
    HapticFeedback.mediumImpact();
    final lines = _linesFor(RegionDetector.deviceCountryCode);
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_rounded, color: AppTokens.primary, size: 36),
              const SizedBox(height: 12),
              const Text('You don\'t have to go through this alone',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTokens.onSurface)),
              const SizedBox(height: 8),
              const Text(
                'NeuroCalm is a self-help tool, not emergency care. Talking to a trained person right now can really help. '
                'If you are in immediate danger, call your local emergency number.',
                style: TextStyle(fontSize: 14.5, height: 1.5, color: AppTokens.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ...lines.map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.call_rounded),
                        label: Text('${l.label} · ${l.number}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => launchUrl(Uri(scheme: 'tel', path: l.number)),
                      ),
                    ),
                  )),
              TextButton(
                onPressed: () => launchUrl(Uri.parse('https://findahelpline.com'), mode: LaunchMode.externalApplication),
                child: const Text('Find a helpline in another country'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text('I\'m safe for now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line {
  final String label;
  final String number;
  const _Line(this.label, this.number);
}
