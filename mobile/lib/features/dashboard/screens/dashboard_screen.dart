// cSpell:disable
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core Architecture & Design System
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/adaptive_layout.dart';
import '../../../core/widgets/neuro_button.dart';
import '../../../core/widgets/stateful_view.dart';

// Services
import '../../../core/services/iap_service.dart';
import '../../../core/services/wallet_service.dart';
import '../../../core/bootstrap/post_value_bootstrap.dart';

// Features & Providers
import '../../tracking/providers/streak_provider.dart';
import '../../settings/screens/user_profile_screen.dart';
import '../../therapy/screens/therapy_home_screen.dart';
import '../../voice_therapy/presentation/voice_reframe_screen.dart';
import '../../wallet/presentation/wallet_topup_dialog.dart';
import '../../tracking/screens/habit_calendar_screen.dart';
import '../../journal/screens/journal_timeline_screen.dart';
import '../../growth/widgets/invite_friends_card.dart';
import '../../retention/widgets/retention_cards.dart';

// Monetization
import '../../monetization/widgets/sponsor_reward_card.dart'; // 🚨 NEW: Value-Exchange UI
import '../../monetization/geo_router.dart';
import '../../monetization/services/admob_service.dart';
import '../../monetization/widgets/native_ad_card.dart';
import '../../monetization/widgets/smart_banner_card.dart';

/// The 10/10 Adaptive Dashboard Screen.
/// This screen acts as the central hub of the product architecture[cite: 14]. It actively
/// listens to the design tokens, scales dynamically based on the window size
/// (phone vs. tablet), securely displays the user's local streak data, and
/// seamlessly routes them to the new AI tools and RevenueCat paywalls[cite: 14].
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final IAPService _iapService = IAPService();
  final WalletService _walletService = WalletService();
  
  // State to hold our ad suppression logic for new users
  bool _isInAdGracePeriod = true; 

  @override
  void initState() {
    super.initState();
    _evaluateGracePeriod();
    AdMobService.instance.sdkReadyNotifier.addListener(_evaluateGracePeriod);
    
    // Pre-fetch local SQLite streak data on boot to ensure zero-latency UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(streakProvider);
      // Notifications/referrals only after the user has reached value.
      PostValueBootstrap.run();
    });
  }

  @override
  void dispose() {
    AdMobService.instance.sdkReadyNotifier.removeListener(_evaluateGracePeriod);
    super.dispose();
  }

  /// FIX: ads used to stay hidden until the user had *rated* 3 insights
  /// (`total_investments`), which most users never do — so most users never
  /// saw a single ad. Grace is now based on app sessions (Remote Config).
  Future<void> _evaluateGracePeriod() async {
    // Ensures SharedPreferences is warm for other widgets; grace comes from ads.
    await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isInAdGracePeriod = !AdMobService.instance.canServeAds;
      });
    }
  }

  void _triggerHaptic() => HapticFeedback.lightImpact();

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    // 10/10 Adaptive System: Determines spacing based on physical window size[cite: 14]
    final horizontalPadding = AdaptiveLayout.getHorizontalPadding(context);
    final sizeClass = AdaptiveLayout.getSizeClass(context);

    return Scaffold(
      backgroundColor: AppTokens.background,
      bottomNavigationBar: const SmartBannerCard(),
      body: SafeArea(
        child: StatefulView(
          state: ViewState.content,
          content: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: AppTokens.spacing24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: AppTokens.spacing32),

                  // Win-back: resume an unfinished reflection or welcome back.
                  const ReturnCard(),

                  _buildHeroCard(),
                  const SizedBox(height: AppTokens.spacing24),

                  // Adaptive Layout: Row on Tablets/Desktop, Column on Mobile[cite: 14]
                  if (sizeClass == WindowSizeClass.compact) ...[
                    _buildMetricsRow(),
                    const SizedBox(height: AppTokens.spacing32),
                    _buildNavigationMenu(),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildNavigationMenu()),
                        const SizedBox(width: AppTokens.spacing24),
                        Expanded(
                          flex: 1,
                          child: _buildMetricsRow(isVertical: true),
                        ),
                      ],
                    ),
                  ],

                  const PatternReportCard(),
                  const SizedBox(height: AppTokens.spacing24),
                  _buildDailyAllowancePill(),
                  const SizedBox(height: AppTokens.spacing16),
                  const InviteFriendsCard(),

                  // Value-exchange sponsor card + native ad (free tier only)
                  _buildSponsorRewardGateway(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // UI COMPONENTS[cite: 14]
  // ===========================================================================

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getTimeBasedGreeting(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTokens.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.spacing4),
            Text(
              "Ready to center yourself?",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppTokens.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Semantics(
          label: "User Profile and Settings",
          button: true,
          child: GestureDetector(
            onTap: () {
              _triggerHaptic();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: const BoxDecoration(
                color: AppTokens.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppTokens.primary,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Semantics(
      container: true,
      label:
          'AI Therapy Engine. Clear your mind. Vocalize your anxious thoughts securely.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTokens.spacing32),
        decoration: BoxDecoration(
          color: AppTokens.primary,
          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppTokens.primary.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: AppTokens.spacing4,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              ),
              child: const Text(
                "60-SECOND REFRAME",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spacing16),
            const Text(
              "Clear your mind.",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppTokens.spacing8),
            Text(
              "Say what's on your mind. In seconds you get a calm, structured CBT reframe and one small next step.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTokens.spacing32),

            // Using our 10/10 Design System Button[cite: 14]
            NeuroButton(
              label: "Begin Voice Session",
              icon: Icons.mic_none_rounded,
              onPressed: () {
                _triggerHaptic();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoiceReframeScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow({bool isVertical = false}) {
    final streakState = ref.watch(streakProvider);

    final metrics = [
      // 1. Streak Tracker (Reads from SQLite Provider)[cite: 14]
      Expanded(
        child: _buildMetricCard(
          icon: Icons.local_fire_department_rounded,
          iconColor: AppTokens.warning,
          title: "Consistency",
          value: streakState.when(
            data: (state) => "${state.currentStreak} Days",
            loading: () => "...",
            error: (error, stack) => "0 Days",
          ),
          onTap: () {
            _triggerHaptic();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HabitCalendarScreen()),
            );
          },
        ),
      ),
      if (!isVertical) const SizedBox(width: AppTokens.spacing16),
      if (isVertical) const SizedBox(height: AppTokens.spacing16),

      // 2. Wallet & Premium Status Tracker (Reads from RevenueCat & Local Wallet)[cite: 14]
      Expanded(
        child: StreamBuilder<bool>(
          stream: _iapService.premiumStatusStream,
          initialData: _iapService.isPremium,
          builder: (context, premiumSnapshot) {
            final isPremium = premiumSnapshot.data ?? false;

            if (isPremium) {
              return _buildMetricCard(
                icon: Icons.workspace_premium_rounded,
                iconColor: AppTokens.secondary,
                title: "Access",
                value: "Premium",
              );
            }

            // If free tier, show Indian UPI Sachet Wallet Balance[cite: 14]
            return StreamBuilder<int>(
              stream: _walletService.balanceStream,
              initialData: _walletService.currentBalance,
              builder: (context, walletSnapshot) {
                final balance = walletSnapshot.data ?? 0;
                return _buildMetricCard(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppTokens.primary,
                  title: "Wallet",
                  value: "$balance Credits",
                  onTap: () {
                    _triggerHaptic();
                    showDialog(
                      context: context,
                      builder: (_) => const WalletTopUpDialog(),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    ];

    return isVertical ? Column(children: metrics) : Row(children: metrics);
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: onTap != null,
      label: '$title: $value',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTokens.spacing16),
          decoration: BoxDecoration(
            color: AppTokens.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            border: Border.all(
              color: AppTokens.onSurfaceVariant.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: AppTokens.spacing8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTokens.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Explore",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTokens.onSurface,
          ),
        ),
        const SizedBox(height: AppTokens.spacing16),

        _buildNavTile(
          icon: Icons.grid_view_rounded,
          title: "Tools Library",
          subtitle: "Somatic grounding, sleep mode, and more.",
          onTap: () {
            _triggerHaptic();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ToolsLibraryScreen()),
            );
          },
        ),
        const SizedBox(height: 12.0),

        _buildNavTile(
          icon: Icons.history_edu_rounded,
          title: "My Journal",
          subtitle: "Your entries stay on this device.",
          onTap: () {
            _triggerHaptic();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JournalTimelineScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppTokens.spacing16),
          decoration: BoxDecoration(
            color: AppTokens.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            border: Border.all(
              color: AppTokens.onSurfaceVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppTokens.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                ),
                child: Icon(icon, color: AppTokens.primary, size: 22),
              ),
              const SizedBox(width: AppTokens.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTokens.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spacing4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTokens.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows how many free AI reflections remain today — the daily "reason to
  /// come back" (resets every day) and a gentle nudge toward the sponsor card.
  Widget _buildDailyAllowancePill() {
    if (_iapService.isPremium) return const SizedBox.shrink();
    return StreamBuilder<int>(
      stream: _walletService.balanceStream,
      builder: (context, _) => _allowancePillBody(),
    );
  }

  Widget _allowancePillBody() {
    final free = _walletService.freeRemaining;
    final daily = _walletService.freeDaily;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.primaryContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTokens.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              free > 0
                  ? '$free of $daily free reflections left today'
                  : 'Free reflections refresh tomorrow · credits still work',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTokens.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// Free tier: sponsor (rewarded) card when credits run low, plus one
  /// clearly-labelled native ad. Premium and first-session users see neither.
  Widget _buildSponsorRewardGateway() {
    if (_isInAdGracePeriod || _iapService.isPremium) {
      return const SizedBox(height: AppTokens.spacing32);
    }

    final routingState = ref.watch(geoRouterProvider);

    return routingState.when(
      data: (accessData) {
        if (accessData.type != MonetizationType.adSupported) {
          return const SizedBox(height: AppTokens.spacing32);
        }
        return StreamBuilder<int>(
          stream: _walletService.balanceStream,
          initialData: _walletService.currentBalance,
          builder: (context, snap) {
            final balance = snap.data ?? 0;
            final lowOnCredits = balance < 5 || _walletService.freeRemaining <= 1;
            return Column(
              children: [
                if (lowOnCredits)
                  const Padding(
                    padding: EdgeInsets.only(top: AppTokens.spacing24),
                    child: SponsorRewardCard(),
                  ),
                const NativeAdCard(),
                const SizedBox(height: AppTokens.spacing24),
              ],
            );
          },
        );
      },
      loading: () => const SizedBox(height: AppTokens.spacing32),
      error: (error, stack) => const SizedBox(height: AppTokens.spacing32),
    );
  }
}
