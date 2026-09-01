import 'package:flutter/material.dart';

// ============================================================================
// CORE NAVIGATION ROUTING (60 FPS Fluid Transitions)
// ============================================================================
/// Centralized animation configurations to guarantee fluid, stutter-free 
/// transitions across the entire application hierarchy. 
class NeuroCalmTransitions {
  static const Duration defaultDuration = Duration(milliseconds: 600);
  static const Duration quickDuration = Duration(milliseconds: 400);
  static const Curve defaultCurve = Curves.easeOutCubic;

  /// Premium Fade & Scale transition (Mimics native iOS depth and glassmorphism reveals)
  static Route<T> fadeScale<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: defaultDuration,
      reverseTransitionDuration: quickDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: defaultCurve),
        );
        final scale = Tween<double>(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: defaultCurve),
        );
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }

  /// Fluid slide from right to left with slight fade (Standard hierarchy push)
  static Route<T> slideRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: defaultDuration,
      reverseTransitionDuration: quickDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: defaultCurve),
        );
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: defaultCurve),
        );
        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: fade, child: child),
        );
      },
    );
  }

  /// Slide up from the bottom (Used for modals, paywalls, and heavy interruptions)
  static Route<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: defaultDuration,
      reverseTransitionDuration: quickDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
        );
        return SlideTransition(
          position: slide,
          child: child,
        );
      },
    );
  }
}

// ============================================================================
// SKELETON LOADING SHIMMER (Eliminates Content Jumps)
// ============================================================================
/// Reusable skeleton loader to maintain layout stability and prevent visual 
/// flickering while async data (Firebase/SQLite) is being resolved.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 20.0,
    this.borderRadius = 12.0,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: const Color(0xFFE2E8F0), // Slate 200
      end: const Color(0xFFF1F5F9),   // Slate 100
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

// ============================================================================
// STAGGERED LIST ANIMATOR (Waterfall Effect)
// ============================================================================
/// Wraps list items to create a smooth, staggered cascading entrance animation.
class StaggeredFadeIn extends StatelessWidget {
  final Widget child;
  final int index;
  final double delayMultiplier;

  const StaggeredFadeIn({
    super.key,
    required this.child,
    required this.index,
    this.delayMultiplier = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, _) {
        // Calculate dynamic delay offset based on list position
        final delay = (index * delayMultiplier).clamp(0.0, 1.0);
        final adjustedValue = ((value - delay) / (1 - delay)).clamp(0.0, 1.0);
        
        return Opacity(
          opacity: adjustedValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - adjustedValue)),
            child: child,
          ),
        );
      },
    );
  }
}