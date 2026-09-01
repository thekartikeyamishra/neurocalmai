import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// HAPTIC-RICH SPRING BUTTON
// ============================================================================
/// A highly reusable, premium button component that physically responds to 
/// user interaction. By compressing slightly on tap down and springing back 
/// on release, it provides immediate tactile gratification that drives engagement.
class SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? shadowColor;
  final double height;
  final double width;
  final double borderRadius;
  final bool isHeavyHaptic;
  final bool isSecondary;

  const SpringButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.shadowColor,
    this.height = 56.0,
    this.width = double.infinity,
    this.borderRadius = 16.0,
    this.isHeavyHaptic = false,
    this.isSecondary = false,
  });

  @override
  State<SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<SpringButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeOutBack, // Spring back effect
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    
    // Immediate physiological feedback matching the button's visual compression
    if (widget.isHeavyHaptic) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    
    _controller.reverse();
    // Intentional micro-delay ensures the spring animation is felt before routing
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) widget.onPressed!();
    });
  }

  void _handleTapCancel() {
    if (widget.onPressed == null) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = widget.onPressed == null;
    
    // Dynamic styling based on primary vs secondary roles
    final Color bgColor = widget.backgroundColor ?? 
        (widget.isSecondary ? theme.colorScheme.surface : theme.colorScheme.primary);
    
    final Color borderColor = widget.isSecondary 
        ? theme.colorScheme.outline.withValues(alpha: 0.3)
        : Colors.transparent;

    final Color effectiveShadowColor = widget.shadowColor ?? 
        (widget.isSecondary ? Colors.black : theme.colorScheme.primary);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: isDisabled 
                ? theme.colorScheme.onSurface.withValues(alpha: 0.1) 
                : bgColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: isDisabled ? Colors.transparent : borderColor,
              width: 1.5,
            ),
            boxShadow: (isDisabled || widget.isSecondary) ? [] : [
              BoxShadow(
                color: effectiveShadowColor.withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Center(
            child: Opacity(
              opacity: isDisabled ? 0.5 : 1.0,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}