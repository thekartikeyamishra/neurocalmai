import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers
import '../../tracking/providers/streak_provider.dart';

// Screens
import '../../settings/screens/user_profile_screen.dart';
import '../../therapy/screens/voice_therapy_screen.dart';
import '../../emotion/screens/emotion_scan_screen.dart';
import '../../therapy/screens/breathing_screen.dart';
import '../../journal/screens/journal_timeline_screen.dart';
// 🚨 NEW IMPORT: Accessing the newly refactored Tools Library
import '../../therapy/screens/therapy_home_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // 🚨 ARCHITECT FIX: Added therapeutic staggered entry animations
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final streakState = ref.watch(streakProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context, theme),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dynamic Greeting
                      Text(
                        _getDynamicGreeting(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildStreakCard(streakState, theme),
                      
                      const SizedBox(height: 36),
                      _buildSectionHeader(theme, "Daily Check-in"),
                      const SizedBox(height: 16),
                      _buildMainActions(context, theme),
                      
                      const SizedBox(height: 36),
                      
                      // 🚨 ARCHITECT FIX: Added "See all" routing to the new ToolsLibraryScreen
                      _buildSectionHeader(
                        theme, 
                        "Recovery Tools", 
                        onSeeAll: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => const ToolsLibraryScreen())
                          );
                        }
                      ),
                      const SizedBox(height: 16),
                      _buildToolGrid(context, theme),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 80.0,
      floating: false,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 24, bottom: 16),
        title: Text(
          'NeuroCalm',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 24.0, top: 8.0),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen()));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1), // Fixed deprecated opacity
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.person_rounded, 
                color: theme.colorScheme.primary, 
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(dynamic streakState, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3), // Fixed deprecated opacity
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 48),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${streakState.currentStreak} Day Streak',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep your momentum going.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary.withValues(alpha: 0.8),
            letterSpacing: 0.5,
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Row(
              children: [
                Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: theme.colorScheme.primary),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMainActions(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            'Face Scan',
            Icons.face_retouching_natural_rounded,
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.primary,
            const EmotionScanScreen(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionCard(
            context,
            'Talk to AI',
            Icons.mic_none_rounded,
            theme.colorScheme.primary,
            Colors.white,
            const VoiceTherapyScreen(),
            hasShadow: true, // Draws attention to the primary CBT feature
          ),
        ),
      ],
    );
  }

  Widget _buildToolGrid(BuildContext context, ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildToolItem(context, theme, 'Panic Mode', Icons.waves_rounded, const BreathingScreen(), isAlert: true),
        _buildToolItem(context, theme, 'My Journal', Icons.history_edu_rounded, const JournalTimelineScreen()),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String label, IconData icon, Color bg, Color text, Widget screen, {bool hasShadow = false}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: bg, 
          borderRadius: BorderRadius.circular(24),
          boxShadow: hasShadow ? [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: text, size: 32),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolItem(BuildContext context, ThemeData theme, String label, IconData icon, Widget screen, {bool isAlert = false}) {
    return GestureDetector(
      onTap: () {
        isAlert ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      child: Container(
        decoration: BoxDecoration(
          color: isAlert ? const Color(0xFFFFF0EC) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAlert ? Colors.deepOrange.withValues(alpha: 0.1) : theme.colorScheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isAlert ? Colors.deepOrange : theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label, 
              style: TextStyle(
                fontWeight: FontWeight.w700, 
                color: isAlert ? Colors.deepOrange[800] : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}