import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicalDisclaimerOverlay extends StatefulWidget {
  final VoidCallback onConsentGranted;

  const MedicalDisclaimerOverlay({
    super.key, 
    required this.onConsentGranted,
  });

  /// 🚨 LEGAL LOGIC: Helper to check if the app needs to show this screen on launch
  static Future<bool> requiresConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('medical_consent_granted') ?? false);
  }

  @override
  State<MedicalDisclaimerOverlay> createState() => _MedicalDisclaimerOverlayState();
}

class _MedicalDisclaimerOverlayState extends State<MedicalDisclaimerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isCheckboxChecked = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    
    // Smooth, authoritative entrance animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// 🚨 LEGAL & UX LOGIC: Securely saves explicit consent
  Future<void> _handleConsent() async {
    if (!_isCheckboxChecked || _isProcessing) return;

    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('medical_consent_granted', true);
      // Cryptographic-style timestamp logging for compliance auditing
      await prefs.setString('medical_consent_timestamp', DateTime.now().toUtc().toIso8601String());
      
      // Allow the animation to finish before unmounting
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        widget.onConsentGranted();
      }
    } catch (e) {
      debugPrint('🚨 [Consent Save Error]: $e');
      setState(() => _isProcessing = false);
    }
  }

  void _toggleCheckbox() {
    HapticFeedback.selectionClick();
    setState(() {
      _isCheckboxChecked = !_isCheckboxChecked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 🚨 SECURITY: PopScope completely disables the Android hardware back button
    // The user CANNOT bypass this screen without accepting.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Premium Midnight background
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Iconography
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded, 
                        size: 56, 
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Title
                    const Text(
                      "Important Safety\nDisclaimer",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Scrollable Legal Text to support smaller devices
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDisclaimerPoint(
                                "1. General Wellness Tool",
                                "NeuroCalm AI is designed exclusively for mindfulness, habit tracking, and general wellness. It is not a medical device.",
                              ),
                              _buildDisclaimerPoint(
                                "2. No Medical Advice",
                                "This application does not diagnose, treat, cure, or prevent any clinical mental health conditions (such as Clinical Depression, PTSD, or Anxiety Disorders).",
                              ),
                              _buildDisclaimerPoint(
                                "3. AI Limitations",
                                "The insights provided by the AI engine are for educational self-reflection only and should never override professional psychiatric advice.",
                              ),
                              _buildDisclaimerPoint(
                                "4. Emergency Situations",
                                "If you are experiencing a mental health crisis, severe panic, or having thoughts of self-harm, close this app immediately and contact your local emergency services or a medical professional.",
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 🚨 EXPLICIT CONSENT CHECKBOX
                    GestureDetector(
                      onTap: _toggleCheckbox,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _isCheckboxChecked ? const Color(0xFF38BDF8) : Colors.transparent,
                              border: Border.all(
                                color: _isCheckboxChecked ? const Color(0xFF38BDF8) : Colors.white54,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _isCheckboxChecked
                                ? const Icon(Icons.check_rounded, size: 20, color: Color(0xFF0F172A))
                                : null,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              "I have read and fully understand the safety limitations of this application.",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action Button (Disabled until checkbox is checked)
                    SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isCheckboxChecked ? _handleConsent : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: const Color(0xFF0F172A),
                          disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                          disabledForegroundColor: Colors.white38,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                                ),
                              )
                            : const Text(
                                "I Understand and Agree",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimerPoint(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}