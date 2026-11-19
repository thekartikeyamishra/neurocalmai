import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A production-ready gamification widget rendering an animated "Cognitive Tree".
/// Dynamically grows branches, foliage density, and unlocks cosmetic floral blooms
/// based on the user's weekly CBT streak (0 to 7 days).
class CognitiveTreeWidget extends StatefulWidget {
  /// The user's active streak count for the current week (clamped 0 to 7).
  final int streakDays;

  /// Optional dimension size for the square canvas.
  final double size;

  /// Callback triggered when the tree is tapped for micro-interaction feedback.
  final VoidCallback? onTap;

  const CognitiveTreeWidget({
    super.key,
    required this.streakDays,
    this.size = 280.0,
    this.onTap,
  });

  @override
  State<CognitiveTreeWidget> createState() => _CognitiveTreeWidgetState();
}

class _CognitiveTreeWidgetState extends State<CognitiveTreeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _growthController;
  late Animation<double> _growthAnimation;

  @override
  void initState() {
    super.initState();
    _growthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _growthAnimation = CurvedAnimation(
      parent: _growthController,
      curve: Curves.easeOutCubic,
    );

    _growthController.forward();
  }

  @override
  void didUpdateWidget(covariant CognitiveTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streakDays != widget.streakDays) {
      _growthController.reset();
      _growthController.forward();
    }
  }

  @override
  void dispose() {
    _growthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int clampedStreak = widget.streakDays.clamp(0, 7);
    final double stageFactor = clampedStreak / 7.0;

    return GestureDetector(
      onTap: () {
        _growthController.forward(from: 0.0);
        widget.onTap?.call();
      },
      child: Center(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF2E6F56).withAlpha(35),
                const Color(0xFF1E3A2F).withAlpha(10),
                Colors.transparent,
              ],
              stops: const [0.4, 0.8, 1.0],
            ),
          ),
          child: AnimatedBuilder(
            animation: _growthAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _CognitiveTreePainter(
                  progress: _growthAnimation.value * (stageFactor == 0 ? 0.1 : stageFactor),
                  streakDays: clampedStreak,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CognitiveTreePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 based on streak progress
  final int streakDays;

  _CognitiveTreePainter({
    required this.progress,
    required this.streakDays,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.88);
    final maxTrunkHeight = size.height * 0.38;

    // Ground line / root base
    final groundPaint = Paint()
      ..color = const Color(0xFF1E3A2F).withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - (size.width * 0.22), center.dy),
      Offset(center.dx + (size.width * 0.22), center.dy),
      groundPaint,
    );

    // Root glow
    final rootGlowPaint = Paint()
      ..color = const Color(0xFF2E6F56).withAlpha(40)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - (size.width * 0.14), center.dy),
      Offset(center.dx + (size.width * 0.14), center.dy),
      rootGlowPaint,
    );

    // Trunk Paint
    final trunkPaint = Paint()
      ..color = const Color(0xFF1E3A2F)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;

    final trunkTop = Offset(
      center.dx,
      center.dy - (maxTrunkHeight * progress.clamp(0.1, 1.0)),
    );

    // Draw primary trunk
    canvas.drawLine(center, trunkTop, trunkPaint);

    if (progress > 0.2) {
      final branchProgress = ((progress - 0.2) / 0.8).clamp(0.0, 1.0);
      _drawBranches(canvas, trunkTop, size, branchProgress);
    }
  }

  void _drawBranches(Canvas canvas, Offset start, Size size, double branchProgress) {
    final branchPaint = Paint()
      ..color = const Color(0xFF2E6F56)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5;

    final leafPaint = Paint()
      ..color = const Color(0xFF4E9F3D)
      ..style = PaintingStyle.fill;

    final bloomPaint = Paint()
      ..color = const Color(0xFFFFB26B)
      ..style = PaintingStyle.fill;

    // Primary left branch
    final leftBranchTarget = Offset(
      start.dx - (size.width * 0.22 * branchProgress),
      start.dy - (size.height * 0.16 * branchProgress),
    );
    canvas.drawLine(start, leftBranchTarget, branchPaint);

    // Primary right branch
    final rightBranchTarget = Offset(
      start.dx + (size.width * 0.24 * branchProgress),
      start.dy - (size.height * 0.14 * branchProgress),
    );
    canvas.drawLine(start, rightBranchTarget, branchPaint);

    // Central crown branch
    final centerBranchTarget = Offset(
      start.dx + (size.width * 0.02),
      start.dy - (size.height * 0.22 * branchProgress),
    );
    canvas.drawLine(start, centerBranchTarget, branchPaint);

    // Sub-branches if streak >= 3
    if (streakDays >= 3 && branchProgress > 0.5) {
      final subBranchPaint = Paint()
        ..color = const Color(0xFF3B8164)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      final subLeft = Offset(
        leftBranchTarget.dx - (size.width * 0.08 * branchProgress),
        leftBranchTarget.dy - (size.height * 0.09 * branchProgress),
      );
      final subRight = Offset(
        rightBranchTarget.dx + (size.width * 0.09 * branchProgress),
        rightBranchTarget.dy - (size.height * 0.08 * branchProgress),
      );

      canvas.drawLine(leftBranchTarget, subLeft, subBranchPaint);
      canvas.drawLine(rightBranchTarget, subRight, subBranchPaint);

      // Render leaves at branch terminals
      final leafRadius = 7.0 * branchProgress;
      canvas.drawCircle(subLeft, leafRadius, leafPaint);
      canvas.drawCircle(subRight, leafRadius, leafPaint);
    }

    // Foliage Clusters scaled by streak days
    final foliageRadius = (10.0 + (streakDays * 3.5)) * branchProgress;
    canvas.drawCircle(leftBranchTarget, foliageRadius * 0.8, leafPaint);
    canvas.drawCircle(rightBranchTarget, foliageRadius * 0.85, leafPaint);
    canvas.drawCircle(centerBranchTarget, foliageRadius, leafPaint);

    // Cosmetic blooms unlocked at streak milestones (Day 5 & Day 7)
    if (streakDays >= 5 && branchProgress > 0.8) {
      final double bloomRadius = 5.5 * branchProgress;
      canvas.drawCircle(
        Offset(centerBranchTarget.dx - 14, centerBranchTarget.dy - 6),
        bloomRadius,
        bloomPaint,
      );
      canvas.drawCircle(
        Offset(rightBranchTarget.dx + 8, rightBranchTarget.dy - 4),
        bloomRadius,
        bloomPaint,
      );
    }

    if (streakDays >= 7 && branchProgress > 0.9) {
      // Golden Crown Bloom on completion of full week
      final goldenBloom = Paint()
        ..color = const Color(0xFFFFD93D)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(centerBranchTarget.dx, centerBranchTarget.dy - 12),
        7.5 * branchProgress,
        goldenBloom,
      );
      canvas.drawCircle(
        Offset(leftBranchTarget.dx - 10, leftBranchTarget.dy - 8),
        5.5 * branchProgress,
        bloomPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CognitiveTreePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.streakDays != streakDays;
  }
}