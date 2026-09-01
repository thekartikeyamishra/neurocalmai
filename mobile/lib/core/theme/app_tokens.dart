import 'package:flutter/material.dart';

/// Centralized Design Tokens for a 10/10 Adaptive Design System.
/// Avoids hardcoded magic numbers across the app.
class AppTokens {
  // --- COLOR PALETTE ---
  // Premium, calm, trustworthy
  static const Color primary = Color(0xFF2F5244); // Deep Sage
  static const Color primaryContainer = Color(0xFFE4F0EB);
  static const Color secondary = Color(0xFFD9A071); // Warm Amber
  static const Color surface = Color(0xFFFBFAF6); // Calm Cream
  static const Color surfaceContainer = Colors.white;
  static const Color background = Color(0xFFFBFAF6);
  static const Color onSurface = Color(0xFF1E293B); // Slate 800
  static const Color onSurfaceVariant = Color(0xFF64748B); // Slate 500

  // Semantic States
  static const Color error = Color(0xFFDC2626);
  static const Color errorContainer = Color(0xFFFEF2F2);
  static const Color success = Color(0xFF16A34A);
  static const Color successContainer = Color(0xFFF0FDF4);
  static const Color warning = Color(0xFFD97706);

  // --- SPACING (8-Point Grid) ---
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;
  static const double spacing64 = 64.0;

  // --- BORDER RADII ---
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusPill = 999.0;

  // --- TOUCH TARGETS (Accessibility) ---
  static const double minTouchTarget = 44.0;
}