// cSpell:ignore Neuro, neuro
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase Auto-Generated Options
import 'firebase_options.dart';

// Core Design System & Services
import 'core/theme/app_tokens.dart';
import 'core/services/iap_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/remote_config_service.dart'; // 🚨 NEW: Cloud Configuration
import 'core/services/wallet_service.dart'; // 🚨 NEW: Hooked Economics

// Feature Screens & Services
import 'features/auth/screens/auth_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/monetization/services/admob_service.dart';
import 'features/notifications/services/push_notification_service.dart';

void main() async {
  // 1. Zone Guarding for Production Stability: Catches all uncaught async errors[cite: 15]
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 2. Load Environment Variables (API Keys Vault)[cite: 15]
      try {
        await dotenv.load(fileName: ".env");
        debugPrint('✅ Environment variables loaded successfully.');
      } catch (e) {
        debugPrint(
          '⚠️ Could not load .env file. Running with compile-time defaults: $e',
        );
      }

      // 3. Initialize Firebase Securely[cite: 15]
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase initialized successfully.');
      } catch (e) {
        debugPrint(
          '⚠️ Firebase initialization error (Offline Mode Active): $e',
        );
      }

      // 4. Initialize Remote Config (Cloud AI Routing & Failsafes)
      try {
        await RemoteConfigService().init();
      } catch (e) {
        debugPrint('⚠️ RemoteConfig initialization error: $e');
      }

      // 5. Initialize In-App Purchases (RevenueCat) with User Context[cite: 15]
      try {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        await IAPService().init(currentUid);
        debugPrint('✅ RevenueCat IAP initialized.');
      } catch (e) {
        debugPrint('⚠️ IAP initialization error: $e');
      }

      // 6. Initialize Wallet Service (300 Credit Welcome Bonus & Sync)
      try {
        await WalletService().init();
        debugPrint('✅ Wallet Service initialized.');
      } catch (e) {
        debugPrint('⚠️ Wallet initialization error: $e');
      }

      // 7. Initialize AdMob Service[cite: 15]
      try {
        await AdMobService.instance.initialize();
        debugPrint('✅ AdMob SDK initialized.');
      } catch (e) {
        debugPrint('⚠️ AdMob initialization error (Running offline): $e');
      }

      // 8. Initialize Zero-Cost Local & Remote Notifications[cite: 15]
      try {
        await LocalNotificationService().init();
        await PushNotificationService.instance.initialize();
        debugPrint('✅ Notification services initialized.');
      } catch (e) {
        debugPrint('⚠️ Notification initialization warning: $e');
      }

      // 9. Lock Orientation & System UI to Guarantee Design Tokens[cite: 15]
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppTokens.background,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      // 10. Wrap the entire app in Riverpod's ProviderScope for state management[cite: 15]
      runApp(const ProviderScope(child: NeuroCalmApp()));
    },
    (error, stack) {
      debugPrint('🚨 [FATAL ASYNC ERROR]: $error\n$stack');
    },
  );
}

// ============================================================================
// GLOBAL THEME CONFIGURATION[cite: 15]
// ============================================================================
final ThemeData _neuroCalmTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppTokens.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppTokens.primary,
    surface: AppTokens.surface,
    primary: AppTokens.primary,
    error: AppTokens.error,
  ),
  fontFamily: 'Inter',
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.0,
      color: AppTokens.primary,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: AppTokens.onSurface,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: AppTokens.onSurface,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.6, color: AppTokens.onSurface),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.5,
      color: AppTokens.onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppTokens.onSurface,
    ),
  ),
);

class NeuroCalmApp extends StatelessWidget {
  const NeuroCalmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroCalm AI',
      debugShowCheckedModeBanner: false,
      theme: _neuroCalmTheme,
      home: const WelcomeScreen(),
    );
  }
}

// ============================================================================
// BOOTSTRAP / WELCOME SCREEN[cite: 15]
// ============================================================================
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  bool _isRouting = false;
  bool _showButton = false;

  @override
  void initState() {
    super.initState();

    // UI Entry Animations[cite: 15]
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    // Ambient Pulse Animation[cite: 15]
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _entryController.forward().then((_) {
      if (mounted) {
        _pulseController.repeat(reverse: true);
        _checkExistingSession(); // Automatically route if user session exists[cite: 15]
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Evaluates local storage and Firebase Auth to determine the starting destination[cite: 15]
  Future<void> _checkExistingSession() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final hasSeenOnboarding =
          preferences.getBool('has_seen_onboarding') ?? false;

      User? user;
      try {
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {
        user = null;
      }

      // Intentional delay to allow the user to ground themselves visually[cite: 15]
      await Future.delayed(const Duration(milliseconds: 1600));

      if (!mounted) return;

      if (hasSeenOnboarding && user != null) {
        setState(() => _isRouting = true);
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const DashboardScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      } else {
        setState(() => _showButton = true);
      }
    } catch (e) {
      if (mounted) setState(() => _showButton = true);
    }
  }

  Future<void> _handleStartTherapy() async {
    if (_isRouting) return;

    HapticFeedback.selectionClick();
    setState(() => _isRouting = true);

    try {
      final preferences = await SharedPreferences.getInstance();
      final hasSeenOnboarding =
          preferences.getBool('has_seen_onboarding') ?? false;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              hasSeenOnboarding ? const AuthScreen() : const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: scaleAnimation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTokens.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spacing32,
                vertical: 40.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: const BoxDecoration(
                        color: AppTokens.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.spa_rounded,
                        size: 40,
                        color: AppTokens.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40.0),
                  Text(
                    'Find your\ncenter.',
                    style: theme.textTheme.displayLarge,
                  ),
                  const SizedBox(height: 20.0),
                  Text(
                    'Your private, offline-ready space for emotional clarity and cognitive behavioral therapy.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTokens.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(flex: 2),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          size: 16,
                          color: AppTokens.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppTokens.spacing8),
                        Text(
                          '100% Private & Offline-Ready',
                          style: TextStyle(
                            color: AppTokens.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.spacing16),

                  // Start CTA Button[cite: 15]
                  AnimatedOpacity(
                    opacity: _showButton ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 800),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56, // Accessible standard touch target[cite: 15]
                      child: ElevatedButton(
                        onPressed: (_isRouting || !_showButton)
                            ? null
                            : _handleStartTherapy,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusMedium,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: _isRouting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Begin Session',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spacing16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
