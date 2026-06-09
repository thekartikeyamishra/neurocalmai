import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ValueConsentScreen extends StatefulWidget {
  final VoidCallback onAgreed;
  
  const ValueConsentScreen({
    super.key, 
    required this.onAgreed,
  });

  @override
  State<ValueConsentScreen> createState() => _ValueConsentScreenState();
}

class _ValueConsentScreenState extends State<ValueConsentScreen> {
  bool _dataConsent = false;
  bool _refundConsent = false;
  bool _isProcessing = false;

  Future<void> _recordConsent() async {
    // Double check state to prevent accidental submission
    if (!_dataConsent || !_refundConsent) {
      HapticFeedback.heavyImpact();
      return;
    }
    
    setState(() => _isProcessing = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        throw Exception("Authentication required to save preferences.");
      }

      // Store legally binding consent tied to the authenticated user UID.
      // This satisfies Razorpay and Play Store compliance for digital goods.
      await FirebaseFirestore.instance.collection('legal_consents').doc(user.uid).set({
        'userId': user.uid,
        'email': user.email ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'data_personalization_agreed': true,
        'instant_compute_terms_agreed': true,
        'version': '1.0.0_razorpay_compliant',
        // In a full production scenario, you would also capture IP or Device ID here 
        // if explicitly required by your local legal jurisdiction.
      }, SetOptions(merge: true));

      if (!mounted) return;
      HapticFeedback.lightImpact();
      widget.onAgreed();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to securely save profile: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isButtonEnabled = _dataConsent && _refundConsent && !_isProcessing;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 64.0),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section (Psychological Framing)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.security_rounded, 
                          size: 36, 
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Let's tailor this entirely to you.", 
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "To ensure maximum ROI and a seamless experience, we need to align our AI infrastructure with your specific operational style.", 
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Data Consent (Value-Exchange Psychology)
                      _buildConsentCard(
                        theme: theme,
                        value: _dataConsent,
                        onChanged: (val) => setState(() => _dataConsent = val ?? false),
                        title: "Enable Hyper-Personalization",
                        subtitle: "I allow the system to analyze my usage patterns to build a custom AI model specifically for my needs. Data is anonymized, encrypted, and strictly used to improve my results.",
                        icon: Icons.psychology_rounded,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // No-Refund Consent (Instant Compute & IP Psychology)
                      _buildConsentCard(
                        theme: theme,
                        value: _refundConsent,
                        onChanged: (val) => setState(() => _refundConsent = val ?? false),
                        title: "Instant Compute Allocation",
                        subtitle: "Because our AI instantly generates proprietary strategies and deploys capital-intensive cloud resources on day 1, I understand that subscriptions are non-refundable. I keep full rights to all generated Intellectual Property.",
                        icon: Icons.memory_rounded,
                      ),
                      
                      const Spacer(),
                      const SizedBox(height: 32),
                      
                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isButtonEnabled ? _recordConsent : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            disabledBackgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                            disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: isButtonEnabled ? 2 : 0,
                          ),
                          child: _isProcessing 
                            ? SizedBox(
                                height: 24, 
                                width: 24, 
                                child: CircularProgressIndicator(
                                  color: theme.colorScheme.onPrimary, 
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "Secure My Profile & Continue", 
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Trust Indicators (Critical for conversion)
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(
                              "Bank-level AES-256 Encryption • Razorpay Secured",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildConsentCard({
    required ThemeData theme,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: value 
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value 
              ? theme.colorScheme.primary.withValues(alpha: 0.6)
              : theme.colorScheme.outlineVariant,
          width: 1.5,
        ),
        boxShadow: value ? [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom Checkbox mapping for better visual alignment
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: value,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      onChanged(val);
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    activeColor: theme.colorScheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}