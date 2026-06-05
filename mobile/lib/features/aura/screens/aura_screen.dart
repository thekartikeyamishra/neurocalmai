import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart'; // 🚨 ARCHITECT FIX: Standardized native sharing

class AuraScreen extends ConsumerStatefulWidget {
  final int moodScore; // 1 (Distressed) to 10 (Vibrant)
  final String primaryEmotion;

  const AuraScreen({
    super.key,
    required this.moodScore,
    required this.primaryEmotion,
  });

  @override
  ConsumerState<AuraScreen> createState() => _AuraScreenState();
}

class _AuraScreenState extends ConsumerState<AuraScreen> with TickerProviderStateMixin {
  // Entrance Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Continuous "Breathing" Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Local State
  String _aiResponse = "Tuning into your frequency...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // 1. Staggered Entry Animation (Text & Buttons)
    _fadeController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    // 2. Continuous "Breathing" Aura Animation (Glow Effect)
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 3000), // 3-second inhale/exhale cycle
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // Trigger the offline insight generation
    _generateOfflineAuraInsight();
  }

  /// 🚨 ARCHITECT FIX: Offline-First Aura Engine
  /// Generates instant, 0-latency therapeutic insights without relying on expensive cloud APIs.
  Future<void> _generateOfflineAuraInsight() async {
    // Artificial delay to build psychological anticipation ("Tuning in...")
    await Future.delayed(const Duration(milliseconds: 1800));
    
    if (!mounted) return;

    String insight;
    final emotion = widget.primaryEmotion.toLowerCase();

    // Map localized heuristics based on the incoming parameters
    if (widget.moodScore <= 3 || emotion.contains('anxi') || emotion.contains('stress')) {
      insight = "Your energy is processing heavy elements. It is safe to rest, breathe, and let go of what you cannot control.";
    } else if (widget.moodScore <= 6 || emotion.contains('neutral') || emotion.contains('calm')) {
      insight = "Your frequency is balanced and grounded. Maintain this clarity as you move through your day.";
    } else {
      insight = "Your aura is radiating vitality and strength. Channel this vibrant energy into your passions today.";
    }

    setState(() {
      _aiResponse = insight;
      _isLoading = false;
    });
    
    // Reveal the text and trigger a haptic confirmation
    _fadeController.forward();
    HapticFeedback.mediumImpact();
  }

  /// 🚨 DESIGN FIX: Polished, therapeutic gradient palettes
  List<Color> _getAuraGradient() {
    if (widget.moodScore <= 3) {
      return [const Color(0xFFF43F5E), const Color(0xFFF59E0B)]; // Rose to Amber (Processing Stress)
    } else if (widget.moodScore <= 6) {
      return [const Color(0xFF8B5CF6), const Color(0xFF3B82F6)]; // Violet to Blue (Balanced/Calm)
    } else {
      return [const Color(0xFF10B981), const Color(0xFFFBBF24)]; // Emerald to Amber (Vibrant/Happy)
    }
  }

  /// 🚨 VIRALITY FIX: Native share formatting targeting IG Stories & WhatsApp
  void _shareAura() {
    HapticFeedback.heavyImpact();
    final String shareText = 
      "My current emotional aura is resonating with ${widget.primaryEmotion.toUpperCase()}.\n\n"
      "\"$_aiResponse\"\n\n"
      "Scan your own aura privately with NeuroCalm AI: https://neurocalm.ai/aura";
      
    Share.share(shareText, subject: 'My NeuroCalm Aura');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = _getAuraGradient();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.colorScheme.primary),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    // 🚨 UI FIX: The Breathing Aura Card using AnimatedBuilder for 60fps performance
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            gradient: LinearGradient(
                              colors: gradient, 
                              begin: Alignment.topLeft, 
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gradient[0].withValues(alpha: 0.3 + (_pulseAnimation.value * 0.3)), // Glowing pulse
                                blurRadius: 30 + (_pulseAnimation.value * 20), // Expands and contracts
                                spreadRadius: 5 + (_pulseAnimation.value * 10),
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.blur_on_rounded, color: Colors.white, size: 72),
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                "MY CURRENT AURA",
                                style: TextStyle(
                                  fontSize: 13, 
                                  color: Colors.white70, 
                                  fontWeight: FontWeight.w800, 
                                  letterSpacing: 3.0,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.primaryEmotion.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 36, 
                                  fontWeight: FontWeight.w900, 
                                  color: Colors.white, 
                                  letterSpacing: -1.0,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Viral Action Button
                    TextButton.icon(
                      onPressed: _shareAura,
                      icon: Icon(Icons.ios_share_rounded, color: theme.colorScheme.primary),
                      label: Text(
                        "Share to Instagram / WhatsApp", 
                        style: TextStyle(
                          color: theme.colorScheme.primary, 
                          fontSize: 15, 
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),

                    const Spacer(),
                    
                    // Dynamic Insight Area (Loading vs Loaded State)
                    _isLoading 
                      ? AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: 0.4 + (_pulseAnimation.value * 0.6), // Subtle fading text
                              child: Text(
                                _aiResponse,
                                style: TextStyle(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            );
                          },
                        )
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.05)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03), 
                                    blurRadius: 20, 
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: gradient[0], size: 24),
                                  const SizedBox(height: 16),
                                  Text(
                                    '"$_aiResponse"',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16, 
                                      height: 1.6, 
                                      fontWeight: FontWeight.w600, 
                                      color: Colors.grey[800], 
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}