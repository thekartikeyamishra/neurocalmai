import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Monetization & State
import '../../monetization/geo_router.dart';
import '../../monetization/widgets/native_ad_card.dart';

// Therapy Modules
import 'voice_therapy_screen.dart';
import 'text_therapy_screen.dart';
import 'breathing_screen.dart';
import 'sleep_mode_screen.dart';
import '../../emotion/screens/emotion_scan_screen.dart'; 

// Tracking & Journals
import '../../tracking/screens/habit_calendar_screen.dart'; 
import '../../journal/screens/journal_timeline_screen.dart';

// ============================================================================
// TOOLS LIBRARY SCREEN (Formerly TherapyHomeScreen)
// ============================================================================
class ToolsLibraryScreen extends ConsumerWidget {
  const ToolsLibraryScreen({super.key});

  void _triggerHaptic() => HapticFeedback.lightImpact();
  void _triggerHeavyHaptic() => HapticFeedback.heavyImpact();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚨 ARCHITECT FIX: Removed Language/Sensory providers to reduce overhead.
    // This screen is now strictly a structural catalog of tools.
    final routingState = ref.watch(geoRouterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.primary),
          onPressed: () {
            _triggerHaptic();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Tools Library',
          style: TextStyle(
            color: theme.colorScheme.primary, 
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: routingState.when(
        loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary, strokeWidth: 2)),
        error: (err, stack) => Center(child: Text('Error loading library: $err', style: const TextStyle(color: Colors.red))),
        data: (accessData) => FadeTransitionWidget(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your complete toolkit for emotional regulation and cognitive behavioral therapy.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600], height: 1.4),
                ),
                const SizedBox(height: 32),

                // ==========================================
                // SECTION 1: AI Guided Sessions
                // ==========================================
                _buildSectionHeader(theme, 'AI Guided Sessions'),
                const SizedBox(height: 16),
                
                // Featured Primary Tool: Voice Therapy
                GestureDetector(
                  onTap: () {
                    _triggerHeavyHaptic();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceTherapyScreen()));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.85)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 36),
                        ),
                        const SizedBox(width: 20),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Voice Session', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                              SizedBox(height: 4),
                              Text('Talk naturally with AI', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.9, 
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
                      title: 'Emotion Sync',
                      subtitle: 'Visual mood scan',
                      icon: Icons.face_retouching_natural_rounded,
                      onTap: () {
                        _triggerHaptic();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const EmotionScanScreen()));
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),

                // ==========================================
                // SECTION 2: Somatic Grounding
                // ==========================================
                _buildSectionHeader(theme, 'Somatic Grounding'),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.9, 
                  children: [
                    _buildGridCard(
                      context,
                      title: 'Panic Mode',
                      subtitle: 'Regulate your breathing',
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
                      subtitle: 'Wind down effectively',
                      icon: Icons.nightlight_round, 
                      isDark: true,
                      onTap: () {
                        _triggerHaptic();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepModeScreen()));
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // ==========================================
                // SECTION 3: Progress & History
                // ==========================================
                _buildSectionHeader(theme, 'Progress & History'),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.9, 
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
                
                const SizedBox(height: 24),

                // --- INLINE NATIVE ADVANCED AD ---
                if (accessData.type == MonetizationType.adSupported)
                  const NativeAdCard(),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.primary.withValues(alpha: 0.8),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap, bool isAlert = false, bool isDark = false}) {
    final theme = Theme.of(context);
    Color bgColor = theme.colorScheme.surface;
    Color textColor = theme.colorScheme.onSurface;
    Color iconColor = theme.colorScheme.primary;
    Color iconBgColor = theme.colorScheme.primary.withValues(alpha: 0.1); 

    if (isAlert) {
      bgColor = const Color(0xFFFFF0EC); 
      iconColor = Colors.deepOrange;
      iconBgColor = Colors.deepOrange.withValues(alpha: 0.15); 
    } else if (isDark) {
      bgColor = const Color(0xFF1E293B); 
      textColor = Colors.white;
      iconColor = Colors.white;
      iconBgColor = Colors.white.withValues(alpha: 0.15); 
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const Spacer(),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[600], height: 1.2)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REUSABLE FADE TRANSITION
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
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