import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// PREMIUM BADGE WIDGET
// ============================================================================
/// A high-fidelity, animated badge used to celebrate and validate the user's 
/// premium status across the dashboard, profile, and settings screens.
/// Features a continuous, 60FPS fluid shimmer effect to convey high value.
class PremiumBadge extends StatefulWidget {
  final bool isCompact;
  final VoidCallback? onTap;

  const PremiumBadge({
    super.key,
    this.isCompact = false,
    this.onTap,
  });

  @override
  State<PremiumBadge> createState() => _PremiumBadgeState();
}

class _PremiumBadgeState extends State<PremiumBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  // Premium Palette
  final Color _goldDark = const Color(0xFFD97706);
  final Color _goldBase = const Color(0xFFE6A822);
  final Color _goldLight = const Color(0xFFFDE047);
  final Color _premiumText = const Color(0xFF452000);

  @override
  void initState() {
    super.initState();
    
    // Continuous slow shimmer to draw the eye without distracting
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      HapticFeedback.lightImpact();
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget badgeContent = Container(
      padding: widget.isCompact 
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.isCompact ? 8 : 12),
        boxShadow: [
          BoxShadow(
            color: _goldBase.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.isCompact ? 8 : 12),
        child: AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                  colors: [
                    _goldBase,
                    _goldBase,
                    _goldLight, // The moving "shine"
                    _goldBase,
                    _goldDark,
                  ],
                  transform: GradientRotation(_shimmerAnimation.value * 3.14),
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: Container(
                color: Colors.white, // Masked by the shader
                child: child,
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: _premiumText,
                size: widget.isCompact ? 12 : 16,
              ),
              const SizedBox(width: 4),
              Text(
                widget.isCompact ? 'PRO' : 'PREMIUM',
                style: TextStyle(
                  color: _premiumText,
                  fontSize: widget.isCompact ? 10 : 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: badgeContent,
      );
    }

    return badgeContent;
  }
}