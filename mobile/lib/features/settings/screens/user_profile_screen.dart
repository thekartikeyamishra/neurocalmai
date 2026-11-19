import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Services & Providers
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/auth_screen.dart';
import '../../journal/services/local_journal_service.dart';
import '../providers/language_provider.dart';

// 🚨 ARCHITECT FIX: Import the Riverpod providers we need to invalidate after a data wipe
import '../../tracking/providers/streak_provider.dart';

// Sheets & Screens
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/ads/ad_consent_service.dart';
import '../../../core/app_info.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/services/remote_config_service.dart';
import '../../monetization/screens/premium_paywall_screen.dart';
import '../../monetization/services/admob_service.dart';
import 'language_selection_screen.dart';
import '../widgets/sensory_settings_sheet.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  
  void _triggerHaptic(bool isHeavy) {
    isHeavy ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
  }

  // ===========================================================================
  // 1. DATA MANAGEMENT: Secure Wiping (GDPR Right to be Forgotten)
  // ===========================================================================
  Future<void> _confirmDataWipe() async {
    _triggerHaptic(true);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Text('Wipe All Data?', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'This will permanently delete all your offline journals, emotional history, and streak data from this device. This action cannot be undone.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      _triggerHaptic(true);
      
      // Execute 100% Offline SQLite Wipe
      await LocalJournalService.instance.clearAllData();
      
      // 🚨 ARCHITECT FIX: StreakService is deprecated. Streaks run off SQLite natively now.
      // We simply invalidate the Riverpod state so the UI instantly resets to 0.
      ref.invalidate(streakProvider);
      ref.invalidate(journalTimelineProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.delete_sweep_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('All offline data has been securely erased.', style: TextStyle(fontWeight: FontWeight.w600))
                ),
              ],
            ),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(24),
          ),
        );
      }
    }
  }

  // ===========================================================================
  // 2. ACCOUNT MANAGEMENT: Sign Out
  // ===========================================================================
  Future<void> _handleSignOut() async {
    _triggerHaptic(true);
    // Guest (anonymous) accounts cannot be recovered after sign-out: their
    // credits, invite rewards and premium link would be lost forever.
    final isGuest = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
    if (isGuest) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign out of a guest account?'),
          content: const Text(
              'You are using NeuroCalm without an account. Signing out permanently disconnects your credits and any '
              'Premium purchase from this device (journals on this phone are not deleted). Purchases can still be '
              'restored from Google Play with "Restore purchase".'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay signed in')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out anyway')),
          ],
        ),
      );
      if (proceed != true) return;
    }
    await ref.read(authProvider.notifier).signOut();
    
    if (mounted) {
      // Clear the navigation stack to prevent users from pressing "back" into a logged-out state
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _restorePurchase() async {
    _triggerHaptic(false);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await IAPService().restorePurchases();
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? 'Premium restored.' : 'No previous purchase found for this Google account.'),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _openPrivacy() async {
    final url = RemoteConfigService().privacyPolicyUrl;
    if (url.isNotEmpty) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your privacy, plainly'),
        content: const SingleChildScrollView(
          child: Text(
            '• Journals, streaks and mood history are stored only on this phone.\n'
            '• When you ask the AI for a reflection, that text (or voice clip) is sent securely to our server and '
            'to Google\'s Gemini API to generate the reply. We do not store it.\n'
            '• We keep a minimal account record: an anonymous ID, your credit balance, usage counts and purchase status.\n'
            '• Ads are served by Google AdMob according to your consent choices.\n'
            '• Face scans are processed on-device and never uploaded.\n'
            '• You can delete your account and cloud data any time from this screen.',
            style: TextStyle(height: 1.5),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _contactSupport() async {
    _triggerHaptic(false);
    final email = RemoteConfigService().supportEmail;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    if (email.isNotEmpty) {
      final uri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=${Uri.encodeComponent('NeuroCalm help (v${AppInfo.versionName}, id $uid)')}',
      );
      await launchUrl(uri);
      return;
    }
    await launchUrl(Uri.parse(RemoteConfigService().playStoreUrl), mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmAccountDeletion() async {
    _triggerHaptic(true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account and cloud data?'),
        content: const Text(
            'This permanently deletes your credits, usage history and account record from our servers. '
            'Active Google Play subscriptions must be cancelled in Google Play. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('deleteMyData').call<dynamic>();
      await LocalJournalService.instance.clearAllData();
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      messenger.showSnackBar(const SnackBar(content: Text('Your account and cloud data were deleted.')));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not reach the server. Please try again.')));
    }
  }

  // ===========================================================================
  // 3. UI CONSTRUCTION
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeLanguage = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.primary),
          onPressed: () {
            _triggerHaptic(false);
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Settings',
          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // PROFILE HEADER
            _buildAnimatedCard(
              index: 0,
              child: Column(
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.spa_rounded, size: 40, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Anonymous User',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 24, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Private & Encrypted Session',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            Text('PREFERENCES', style: _getSectionHeaderStyle(theme)),
            const SizedBox(height: 12),

            // PREFERENCES GROUP
            _buildAnimatedCard(
              index: 1,
              child: Container(
                decoration: _getCardDecoration(theme),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.language_rounded,
                      title: 'Therapy Dialect',
                      subtitle: activeLanguage.displayName,
                      onTap: () {
                        _triggerHaptic(false);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()));
                      },
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.accessibility_new_rounded,
                      title: 'Sensory & Haptics',
                      subtitle: 'Voice guidance, vibrations',
                      onTap: () {
                        _triggerHaptic(false);
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const SensorySettingsSheet(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            Text('DATA & PRIVACY', style: _getSectionHeaderStyle(theme)),
            const SizedBox(height: 12),

            // PRIVACY GROUP
            _buildAnimatedCard(
              index: 2,
              child: Container(
                decoration: _getCardDecoration(theme),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.shield_rounded,
                      title: 'Privacy Policy',
                      subtitle: 'What stays on your phone and what doesn\'t',
                      onTap: () {
                        _triggerHaptic(false);
                        _openPrivacy();
                      },
                    ),
                    if (AdConsentService.instance.privacyOptionsRequired) ...[
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.tune_rounded,
                        title: 'Privacy & ad choices',
                        subtitle: 'Change your consent at any time',
                        onTap: () async {
                          _triggerHaptic(false);
                          await AdConsentService.instance.showPrivacyOptions();
                          await AdMobService.instance.reinitializeAfterConsentChange();
                        },
                      ),
                    ],
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.workspace_premium_rounded,
                      title: IAPService().isPremium ? 'Premium is active' : 'Go Premium',
                      subtitle: IAPService().isPremium ? 'Thank you for supporting NeuroCalm' : 'No ads, no limits',
                      onTap: () {
                        _triggerHaptic(false);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()));
                      },
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.restore_rounded,
                      title: 'Restore purchase',
                      subtitle: 'New phone? Get Premium back',
                      onTap: _restorePurchase,
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.support_agent_rounded,
                      title: 'Help & feedback',
                      subtitle: 'A real person reads every message',
                      onTap: _contactSupport,
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.person_remove_rounded,
                      title: 'Delete account & cloud data',
                      subtitle: 'Wallet, usage and account record',
                      isDestructive: true,
                      onTap: _confirmAccountDeletion,
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.delete_forever_rounded,
                      title: 'Wipe All Data',
                      subtitle: 'Delete offline journals & streaks',
                      isDestructive: true,
                      onTap: _confirmDataWipe,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            Text('ACCOUNT', style: _getSectionHeaderStyle(theme)),
            const SizedBox(height: 12),

            // ACCOUNT GROUP
            _buildAnimatedCard(
              index: 3,
              child: Container(
                decoration: _getCardDecoration(theme),
                child: _buildSettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Secure Sign Out',
                  subtitle: 'End this session',
                  isDestructive: true,
                  onTap: _handleSignOut,
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // VERSION TAG
            _buildAnimatedCard(
              index: 4,
              child: Center(
                child: Text(
                  'NeuroCalm AI • v${AppInfo.versionName} (${AppInfo.buildNumber})\nSelf-help tool, not a medical service.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // REUSABLE WIDGETS
  // ===========================================================================
  
  TextStyle _getSectionHeaderStyle(ThemeData theme) {
    return TextStyle(
      fontSize: 12, 
      fontWeight: FontWeight.w800, 
      color: Colors.grey[500], 
      letterSpacing: 1.5,
    );
  }

  BoxDecoration _getCardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 60.0, right: 24.0),
      child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.redAccent : const Color(0xFF2A5C5A);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDestructive ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  /// Staggered waterfall animation for list items
  Widget _buildAnimatedCard({required int index, required Widget child}) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, _) {
        // Stagger calculation based on index to create a waterfall cascade effect
        final delay = (index * 0.1).clamp(0.0, 1.0);
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