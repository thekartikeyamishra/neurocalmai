import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';

/// A premium, adaptive cognitive mirror card designed to display detected 
/// cognitive distortions alongside actionable Socratic reframing questions[cite: 11].
/// Incorporates smooth entry animations, semantic accessibility labels, and 
/// centralized design token adherence.
class CognitiveMirrorCard extends StatelessWidget {
  final String rawDistortion;
  final String socraticQuestion;
  final Color? customThemeColor;
  final Duration animationDelay;

  const CognitiveMirrorCard({
    super.key,
    required this.rawDistortion,
    required this.socraticQuestion,
    this.customThemeColor,
    this.animationDelay = const Duration(milliseconds: 100),
  });

  /// Formats raw JSON distortion keys (e.g., "black_and_white_thinking" or "catastrophizing")[cite: 11]
  /// into human-readable, title-cased UI badges ("Black And White Thinking")[cite: 11].
  String _formatDistortion(String input) {
    if (input.trim().isEmpty) return "Unidentified Pattern";
    return input
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = customThemeColor ?? AppTokens.primary;
    final displayDistortion = _formatDistortion(rawDistortion);

    return Semantics(
      container: true,
      label: 'Pattern Detected: $displayDistortion. Reframing question: $socraticQuestion',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTokens.spacing24),
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
            border: Border.all(
              color: baseColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row: Icon + Label
              Row(
                children: [
                  Icon(
                    Icons.psychology_alt_rounded,
                    color: baseColor,
                    size: 22,
                  ),
                  const SizedBox(width: AppTokens.spacing8),
                  Text(
                    "Pattern Detected",
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: baseColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spacing16),

              // The Distortion Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  displayDistortion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.spacing24),

              // Socratic Reframing Question
              Text(
                socraticQuestion,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTokens.onSurface,
                  height: 1.5,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: AppTokens.spacing16),

              // Visual Divider
              Divider(
                color: baseColor.withValues(alpha: 0.15),
                height: 1,
                thickness: 1.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}