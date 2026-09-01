import 'package:flutter/material.dart';

enum WindowSizeClass { compact, medium, expanded }

class AdaptiveLayout {
  /// Determines the WindowSizeClass based on current screen width.
  /// Matches standard Material 3 breakpoints.
  static WindowSizeClass getSizeClass(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return WindowSizeClass.compact; // Phones
    if (width < 840) return WindowSizeClass.medium; // Foldables, small tablets
    return WindowSizeClass.expanded; // Large tablets, desktop
  }

  /// Calculates horizontal padding based on screen size to prevent text from
  /// stretching infinitely on wide displays.
  static double getHorizontalPadding(BuildContext context) {
    final sizeClass = getSizeClass(context);
    switch (sizeClass) {
      case WindowSizeClass.compact:
        return 24.0;
      case WindowSizeClass.medium:
        return 48.0;
      case WindowSizeClass.expanded:
        // On very large screens, constrain the max width of the content
        final width = MediaQuery.sizeOf(context).width;
        return (width - 800) / 2; // Center 800px column
    }
  }
}