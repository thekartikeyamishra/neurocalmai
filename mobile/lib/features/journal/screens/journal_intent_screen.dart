import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🚨 ARCHITECT ROUTING: All 4 Moat Pathways Connected
import 'cbt_wizard_screen.dart';
import 'guided_task_screen.dart';
import 'sleep_dump_screen.dart';
import 'standard_journal_screen.dart';

// ============================================================================
// DATA MODEL: Intent Option
// ============================================================================
class IntentOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color themeColor;
  final String internalRouteId;

  IntentOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.themeColor,
    required this.internalRouteId,
  });
}

// ============================================================================
// UI SCREEN: Journal Intent Triage
// ============================================================================
class JournalIntentScreen extends StatefulWidget {
  const JournalIntentScreen({super.key});

  @override
  State<JournalIntentScreen> createState() => _JournalIntentScreenState();
}

class _JournalIntentScreenState extends State<JournalIntentScreen> with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  // High-Volume Clinical Problems (Derived from search intent data)
  final List<IntentOption> _intents = [
    IntentOption(
      title: "I'm Spiraling",
      subtitle: "Stop racing thoughts and separate facts from anxiety.",
      icon: Icons.all_inclusive_rounded,
      themeColor: const Color(0xFFE11D48), // Rose / Alert
      internalRouteId: 'cbt_wizard',
    ),
    IntentOption(
      title: "I'm Avoiding a Task",
      subtitle: "Break through executive dysfunction and task paralysis.",
      icon: Icons.route_rounded,
      themeColor: const Color(0xFFD97706), // Amber / Action
      internalRouteId: 'adhd_guided',
    ),
    IntentOption(
      title: "I Can't Sleep",
      subtitle: "Brain-dump your racing thoughts to prepare for rest.",
      icon: Icons.nights_stay_rounded,
      themeColor: const Color(0xFF4F46E5), // Indigo / Calm
      internalRouteId: 'sleep_dump',
    ),
    IntentOption(
      title: "Just Reflecting",
      subtitle: "Open-ended space for daily gratitude or general thoughts.",
      icon: Icons.auto_stories_rounded,
      themeColor: const Color(0xFF059669), // Emerald / Growth
      internalRouteId: 'standard_journal',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  void _handleIntentSelection(IntentOption intent) {
    HapticFeedback.heavyImpact(); // Grounding tactile response

    // Exact routing to the appropriate therapeutic workflow
    if (intent.internalRouteId == 'cbt_wizard') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CbtWizardScreen()));
    } else if (intent.internalRouteId == 'adhd_guided') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidedTaskScreen()));
    } else if (intent.internalRouteId == 'sleep_dump') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepDumpScreen()));
    } else if (intent.internalRouteId == 'standard_journal') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const StandardJournalScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              // Header framing
              Text(
                "What's on your mind?",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Select a path so we can provide the exact framework you need right now. No blank page anxiety.",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Intent List with Staggered Animations
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _intents.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final intent = _intents[index];
                    
                    // Calculate staggered animation intervals based on index
                    final start = index * 0.15;
                    final end = (start + 0.4).clamp(0.0, 1.0);
                    
                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(0, 0.2), 
                      end: Offset.zero
                    ).animate(
                      CurvedAnimation(
                        parent: _staggerController,
                        curve: Interval(start, end, curve: Curves.easeOutCubic),
                      ),
                    );

                    final fadeAnimation = Tween<double>(
                      begin: 0.0, 
                      end: 1.0
                    ).animate(
                      CurvedAnimation(
                        parent: _staggerController,
                        curve: Interval(start, end, curve: Curves.easeOutCubic),
                      ),
                    );

                    return FadeTransition(
                      opacity: fadeAnimation,
                      child: SlideTransition(
                        position: slideAnimation,
                        child: _buildIntentCard(theme, intent),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntentCard(ThemeData theme, IntentOption intent) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: intent.themeColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _handleIntentSelection(intent),
          highlightColor: intent.themeColor.withValues(alpha: 0.05),
          splashColor: intent.themeColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: intent.themeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    intent.icon,
                    color: intent.themeColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        intent.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        intent.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action Chevron
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}