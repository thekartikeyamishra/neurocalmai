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

// Features & Providers
import '../../tracking/providers/streak_provider.dart';
import '../../settings/screens/user_profile_screen.dart';
import '../../therapy/screens/therapy_home_screen.dart';
import '../../voice_therapy/presentation/voice_reframe_screen.dart';
import '../../wallet/presentation/wallet_topup_dialog.dart';

// Monetization
import '../../monetization/widgets/sponsor_reward_card.dart'; // 🚨 NEW: Value-Exchange UI
import '../../monetization/geo_router.dart';

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
    
    // Pre-fetch local SQLite streak data on boot to ensure zero-latency UI[cite: 14]
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(streakProvider);
    });
  }

  /// Checks how many sessions the user has completed. 
  /// Hides ads until they are "Hooked" (3+ sessions).
  Future<void> _evaluateGracePeriod() async {
    final prefs = await SharedPreferences.getInstance();
    final totalInvestments = prefs.getInt('total_investments') ?? 0;
    
    if (mounted) {
      setState(() {
        _isInAdGracePeriod = totalInvestments < 3;
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

                  // 🚨 MONETIZATION UPGRADE: Dynamic Sponsor Card
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
                "AI THERAPY ENGINE",
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
              "Vocalize your anxious thoughts securely. Gemini AI will instantly construct a clinical CBT reframe.",
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
            // Future route to HabitCalendar[cite: 14]
            _triggerHaptic();
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
          subtitle: "Review your past offline AI insights.",
          onTap: () {
            _triggerHaptic();
            // Assuming JournalTimelineScreen is connected via ToolsLibrary usually,
            // but providing direct access increases feature discoverability.[cite: 14]
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

  /// 🚨 CHURN REDUCTION GATEWAY
  /// Dynamically replaces basic banner ads with the `SponsorRewardCard` when credits run low.
  Widget _buildSponsorRewardGateway() {
    if (_isInAdGracePeriod || _iapService.isPremium) {
      return const SizedBox(height: AppTokens.spacing32);
    }

    final routingState = ref.watch(geoRouterProvider);
    final currentBalance = _walletService.currentBalance;

    return routingState.when(
      data: (accessData) {
        if (accessData.type == MonetizationType.adSupported) {
          // If the user drops below 50 credits, give them the option to watch an ad
          // instead of forcing a banner on them. 
          if (currentBalance < 50) {
            return const Padding(
              padding: EdgeInsets.only(top: AppTokens.spacing32),
              child: SponsorRewardCard(),
            );
          }
          // Otherwise, normal smooth dashboard experience
          return const SizedBox(height: AppTokens.spacing32);
        }
        return const SizedBox(height: AppTokens.spacing32);
      },
      loading: () => const SizedBox(height: AppTokens.spacing32),
      error: (error, stack) => const SizedBox(height: AppTokens.spacing32),
    );
  }
}
// cSpell:enable