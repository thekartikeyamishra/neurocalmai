import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../therapy/screens/therapy_home_screen.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    // Navigation Listener: Watch auth state and route automatically
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next == AuthState.authenticated) {
        Navigator.pushReplacement(
          context, 
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ToolsLibraryScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          )
        );
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.spa_rounded, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Your Safe Space',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 12),
              Text(
                '100% private. Offline-ready. Secure.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
              const Spacer(),
              
              if (authState == AuthState.error)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    ref.read(authProvider.notifier).errorMessage ?? 'An error occurred',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: authState == AuthState.loading 
                      ? null 
                      : () {
                          HapticFeedback.mediumImpact();
                          ref.read(authProvider.notifier).signInAnonymously();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: authState == AuthState.loading
                      ? const SizedBox(
                          height: 24, width: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text(
                          'Enter Securely',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}