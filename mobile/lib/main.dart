import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase auto-generated file
import 'firebase_options.dart';

// Routing Destinations
import 'features/auth/screens/auth_screen.dart';
import 'features/auth/screens/enhanced_onboarding_screen.dart'; 
import 'features/dashboard/screens/dashboard_screen.dart'; 

// Services
import 'features/monetization/services/admob_service.dart';
// 🚨 ARCHITECT FIX: Removed unused local_journal_service.dart import to fix strict linting errors.

void main() async {
  // 1. Zone Guarding for Production Stability
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Load Environment Variables
    try {
      await dotenv.load(fileName: ".env");
      debugPrint('✅ Environment variables loaded successfully.');
    } catch (e) {
      debugPrint('⚠️ Could not load .env file. Running with local defaults.');
    }

    // 3. Initialize Firebase securely
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully.');
    } catch (e) {
      debugPrint('⚠️ Firebase initialization error (Offline Mode Active): $e');
    }

    // 4. Initialize AdMob Service
    try {
      await AdMobService.instance.initialize();
      debugPrint('✅ AdMob SDK initialized.');
    } catch (e) {
      debugPrint('⚠️ AdMob initialization error (Running offline): $e');
    }

    // 5. Lock orientation & System UI
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFF7F9F9), 
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    runApp(const ProviderScope(child: NeuroCalmApp()));

  }, (error, stack) {
    debugPrint('🚨 [FATAL ASYNC ERROR]: $error');
  });
}

// Global Theme Data
final _neuroCalmTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF7F9F9),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF2A5C5A),
    surface: const Color(0xFFF7F9F9),
    primary: const Color(0xFF2A5C5A),
  ),
  fontFamily: 'Inter', 
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: Color(0xFF2A5C5A)),
    bodyLarge: TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF444444)),
    bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF666666)),
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

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
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

    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 1.0, curve: Curves.easeOut)),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _entryController.forward().then((_) {
      _pulseController.repeat(reverse: true);
      _checkExistingSession();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      final user = FirebaseAuth.instance.currentUser;

      await Future.delayed(const Duration(milliseconds: 2000));

      if (!mounted) return;

      if (hasSeenOnboarding && user != null) {
        setState(() => _isRouting = true);
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const DashboardScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 1000),
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
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
            hasSeenOnboarding ? const AuthScreen() : const EnhancedOnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)
            );
            return FadeTransition(opacity: animation, child: ScaleTransition(scale: scaleAnimation, child: child));
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EnhancedOnboardingScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.spa_rounded, size: 40, color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text('Find your\ncenter.', style: theme.textTheme.displayLarge),
                  const SizedBox(height: 20),
                  Text('Your private, offline-ready space for emotional clarity and cognitive behavioral therapy.', style: theme.textTheme.bodyLarge),
                  const Spacer(flex: 2),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text('100% Private & Offline-Ready', style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    opacity: _showButton ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 800),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: (_isRouting || !_showButton) ? null : _handleStartTherapy,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: _isRouting
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Begin Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}