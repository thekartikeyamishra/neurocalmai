import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core Architecture & Design System
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/adaptive_layout.dart';
import '../../../core/widgets/stateful_view.dart';

// Monetization
import '../../monetization/geo_router.dart';
import '../../monetization/widgets/native_ad_card.dart';

// Therapy Modules
import '../../voice_therapy/presentation/voice_reframe_screen.dart';
import 'text_therapy_screen.dart';
import 'breathing_screen.dart';
import 'sleep_mode_screen.dart';
import '../../somatic/presentation/somatic_grounding_screen.dart';

// Tracking & Journals
import '../../tracking/screens/habit_calendar_screen.dart'; 
import '../../journal/screens/journal_timeline_screen.dart';

/// The 10/10 Adaptive Tools Library Screen.
/// This screen progressively discloses the app's full capabilities and 
/// dynamically adjusts its layout for phones, tablets, and larger screens.
class ToolsLibraryScreen extends ConsumerWidget {
  const ToolsLibraryScreen({super.key});

  void _triggerHaptic() => HapticFeedback.lightImpact();
  void _triggerHeavyHaptic() => HapticFeedback.heavyImpact();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch geoRouterProvider to pull regional dynamic premium requirements
    final routingState = ref.watch(geoRouterProvider);
    final theme = Theme.of(context);
    final horizontalPadding = AdaptiveLayout.getHorizontalPadding(context);
    final sizeClass = AdaptiveLayout.getSizeClass(context);

    return Scaffold(
      backgroundColor: AppTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTokens.primary),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            _triggerHaptic();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Tools Library',
          style: TextStyle(
            color: AppTokens.primary, 
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: routingState.when(
          loading: () => StatefulView(
            state: ViewState.loading,
            content: const SizedBox.shrink(),
            customSkeleton: const Center(
              child: CircularProgressIndicator(color: AppTokens.primary, strokeWidth: 3),
            ),
          ),
          error: (err, stack) => StatefulView(
            state: ViewState.error,
            content: const SizedBox.shrink(),
            errorMessage: 'Error loading library configuration: $err',
            onRetry: () => ref.invalidate(geoRouterProvider),
          ),
          data: (accessData) => FadeTransitionWidget(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: AppTokens.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your complete toolkit for emotional regulation and cognitive behavioral therapy.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTokens.onSurfaceVariant, 
                      height: 1.5, 
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spacing32),

                  // ==========================================
                  // SECTION 1: AI Guided Sessions
                  // ==========================================
                  _buildSectionHeader(theme, 'AI Guided Sessions'),
                  const SizedBox(height: AppTokens.spacing16),
                  
                  // Featured Primary Tool: Voice Therapy Hero Layout
                  Semantics(
                    button: true,
                    label: 'Start a Voice Reframe Session',
                    child: GestureDetector(
                      onTap: () {
                        _triggerHeavyHaptic();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceReframeScreen()));
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTokens.spacing24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTokens.primary, AppTokens.primary.withValues(alpha: 0.85)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
                          boxShadow: [
                            BoxShadow(
                              color: AppTokens.primary.withValues(alpha: 0.25), 
                              blurRadius: 20, 
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2), 
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 36),
                            ),
                            const SizedBox(width: AppTokens.spacing24),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Voice Session', 
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                                  ),
                                  SizedBox(height: AppTokens.spacing4),
                                  Text(
                                    'Talk naturally with AI', 
                                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spacing16),
                  
                  // Adaptive Grid Layout based on Window Size Class
                  GridView.count(
                    crossAxisCount: sizeClass == WindowSizeClass.expanded ? 3 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppTokens.spacing16,
                    crossAxisSpacing: AppTokens.spacing16,
                    childAspectRatio: 0.95, 
                    children: [
                      _buildGridCard(
                        context,
                        title: 'Text Journal',
                        subtitle: 'Type it out securely',
                        icon: Icons.edit_note_rounded,
                        onTap: () {
                          _triggerHaptic();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TextTherapyScreen()));
                        },
                      ),
                      _buildGridCard(
                        context,
                        title: 'Biometrics',
                        subtitle: 'Pulse & panic grounding',
                        icon: Icons.fingerprint_rounded,
                        onTap: () {
                          _triggerHaptic();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SomaticGroundingScreen()));
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppTokens.spacing32),

                  // ==========================================
                  // SECTION 2: Somatic Grounding
                  // ==========================================
                  _buildSectionHeader(theme, 'Somatic Grounding'),
                  const SizedBox(height: AppTokens.spacing16),
                  GridView.count(
                    crossAxisCount: sizeClass == WindowSizeClass.expanded ? 3 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppTokens.spacing16,
                    crossAxisSpacing: AppTokens.spacing16,
                    childAspectRatio: 0.95, 
                    children: [
                      _buildGridCard(
                        context,
                        title: 'Panic Mode',
                        subtitle: 'Regulate breathing',
                        icon: Icons.waves_rounded,
                        isAlert: true,
                        onTap: () {
                          _triggerHeavyHaptic(); 
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const BreathingScreen()));
                        },
                      ),
                      _buildGridCard(
                        context,
                        title: 'Sleep Mode',
                        subtitle: 'Wind down softly',
                        icon: Icons.nightlight_round, 
                        isDark: true,
                        onTap: () {
                          _triggerHaptic();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepModeScreen()));
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTokens.spacing32),

                  // ==========================================
                  // SECTION 3: Progress & History
                  // ==========================================
                  _buildSectionHeader(theme, 'Progress & History'),
                  const SizedBox(height: AppTokens.spacing16),
                  GridView.count(
                    crossAxisCount: sizeClass == WindowSizeClass.expanded ? 3 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppTokens.spacing16,
                    crossAxisSpacing: AppTokens.spacing16,
                    childAspectRatio: 0.95, 
                    children: [
                      _buildGridCard(
                        context,
                        title: 'My Journal',
                        subtitle: 'Past AI insights',
                        icon: Icons.auto_stories_rounded,
                        onTap: () {
                          _triggerHaptic();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalTimelineScreen()));
                        },
                      ),
                      _buildGridCard(
                        context,
                        title: 'Consistency',
                        subtitle: 'View habit streak',
                        icon: Icons.calendar_month_rounded,
                        onTap: () {
                          _triggerHaptic();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitCalendarScreen()));
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppTokens.spacing32),

                  // --- INLINE NATIVE ADVANCED AD MOB GATEWAY ---
                  if (accessData.type == MonetizationType.adSupported)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppTokens.spacing8),
                      child: NativeAdCard(),
                    ),
                  
                  const SizedBox(height: AppTokens.spacing48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: AppTokens.primary.withValues(alpha: 0.85),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context, {
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required VoidCallback onTap, 
    bool isAlert = false, 
    bool isDark = false,
  }) {
    Color bgColor = AppTokens.surfaceContainer;
    Color textColor = AppTokens.onSurface;
    Color iconColor = AppTokens.primary;
    Color iconBgColor = AppTokens.primaryContainer; 

    if (isAlert) {
      bgColor = AppTokens.errorContainer; 
      textColor = AppTokens.error;
      iconColor = Colors.deepOrange;
      iconBgColor = Colors.deepOrange.withValues(alpha: 0.12); 
    } else if (isDark) {
      bgColor = const Color(0xFF1E293B); // Slate 800
      textColor = Colors.white;
      iconColor = const Color(0xFF38BDF8); // AI Cyan
      iconBgColor = Colors.white.withValues(alpha: 0.1); 
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02), 
            blurRadius: 10, 
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spacing24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const Spacer(),
                Text(
                  title, 
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.3),
                ),
                const SizedBox(height: AppTokens.spacing4),
                Text(
                  subtitle, 
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppTokens.onSurfaceVariant, 
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PERFORMANCE OPTIMIZED SMOOTH FADE TRANSITION
// ============================================================================
class FadeTransitionWidget extends StatefulWidget {
  final Widget child;
  const FadeTransitionWidget({super.key, required this.child});

  @override
  State<FadeTransitionWidget> createState() => _FadeTransitionWidgetState();
}

class _FadeTransitionWidgetState extends State<FadeTransitionWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}