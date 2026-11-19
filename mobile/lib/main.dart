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
import 'core/services/remote_config_service.dart';
import 'core/services/wallet_service.dart';
import 'core/navigation/app_navigator.dart';
import 'core/release/force_update_gate.dart';
import 'features/onboarding/presentation/first_win_screen.dart';

// Feature Screens & Services
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/monetization/services/admob_service.dart';
import 'features/retention/services/reengagement_service.dart';

void main() {
  // Zone guard: no uncaught async error can crash the app silently.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('🚨 [FlutterError]: ${details.exceptionAsString()}');
      };

      // 1. Public config only (.env must contain NO secret keys anymore).
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        debugPrint('⚠️ .env not loaded (ok): $e');
      }

      // 2. Firebase is required for auth/AI; failure keeps offline tools alive.
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (e) {
        debugPrint('⚠️ Firebase init error (offline mode): $e');
      }

      // 3. Remote Config: defaults apply instantly, fetch runs in background.
      await RemoteConfigService().init();

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

      // 4. Show UI immediately. Everything below runs in parallel and can
      //    never block or crash the first frame (cold-start retention).
      runApp(const ProviderScope(child: NeuroCalmApp()));
      unawaited(_bootstrapServices());
    },
    (error, stack) {
      debugPrint('🚨 [FATAL ASYNC ERROR]: $error\n$stack');
    },
  );
}

Future<void> _bootstrapServices() async {
  final uid = _safeUid();
  await Future.wait<void>([
    _guard('IAP', () => IAPService().init(uid)),
    _guard('Wallet', () => WalletService().init()),
    // Consent (UMP) runs first inside, then the Ads SDK.
    _guard('Ads', () => AdMobService.instance.initialize()),
    // Welcome-back + win-back notifications (on-device, zero server cost).
    _guard('Reengagement', ReengagementService.instance.start),
  ]);
  // Remote kill-switch for broken builds (after first frame exists).
  await _guard('ForceUpdate', ForceUpdateGate.check);
}

String? _safeUid() {
  try {
    return FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    return null;
  }
}

Future<void> _guard(String name, Future<void> Function() task) async {
  try {
    await task();
  } catch (e) {
    debugPrint('⚠️ [$name] init failed (non-fatal): $e');
  }
}

// ============================================================================
// GLOBAL THEME CONFIGURATION
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
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: _neuroCalmTheme,
      home: const WelcomeScreen(),
    );
  }
}

// ============================================================================
// BOOTSTRAP / WELCOME SCREEN
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

    // UI Entry Animations
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

    // Ambient Pulse Animation
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
        _checkExistingSession(); // Automatically route if user session exists
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Evaluates local storage and Firebase Auth to determine the starting destination
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

      // Short, calm beat (was 1.6s on top of a 1.2s animation = 2.8s wait).
      await Future.delayed(const Duration(milliseconds: 300));

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

      // 🚨 FRICTIONLESS ANONYMOUS ENTRY
      // Instantly generate a secure UID for the user without asking for an email.
      if (FirebaseAuth.instance.currentUser == null) {
        final userCred = await FirebaseAuth.instance.signInAnonymously();
        
        // Immediately bind this new anonymous UID to RevenueCat
        if (userCred.user != null) {
          // Fire-and-forget: billing/wallet must never delay the first win.
          unawaited(IAPService().loginUser(userCred.user!.uid));
          unawaited(WalletService().init());
        }
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          // Bypass the AuthScreen entirely and drop them directly into the app
          pageBuilder: (context, animation, secondaryAnimation) =>
              hasSeenOnboarding ? const DashboardScreen() : const FirstWinScreen(),
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
        setState(() => _isRouting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect securely. Please try again.')),
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
                    'Untangle an anxious thought in under a minute — with CBT tools that keep your journal on your phone.',
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
                        const Text(
                          'Journal stays on your phone · No sign-up',
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

                  // Start CTA Button
                  AnimatedOpacity(
                    opacity: _showButton ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 800),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56, // Accessible standard touch target
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
                                'Start — it\'s free',
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