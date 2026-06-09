import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ValueConsentScreen extends StatefulWidget {
  final VoidCallback onAgreed;
  
  const ValueConsentScreen({
    Key? key, 
    required this.onAgreed,
  }) : super(key: key);

  @override
  State<ValueConsentScreen> createState() => _ValueConsentScreenState();
}

class _ValueConsentScreenState extends State<ValueConsentScreen> {
  bool _dataConsent = false;
  bool _refundConsent = false;
  bool _isProcessing = false;

  Future<void> _recordConsent() async {
    // Double check state
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

      // Store legally binding consent tied to the authenticated user UID
      await FirebaseFirestore.instance.collection('legal_consents').doc(user.uid).set({
        'userId': user.uid,
        'email': user.email ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'data_personalization_agreed': true,
        'instant_compute_terms_agreed': true,
        'version': '1.0.0_razorpay_compliant',
        // In a full production scenario, you would also capture IP or Device ID here 
        // if explicitly required by your local compliance laws.
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
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 64.0),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section (Psychological Framing)
                      Icon(
                        Icons.security_rounded, 
                        size: 48, 
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Let's tailor this entirely to you.", 
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onBackground,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "To ensure maximum ROI and a seamless experience, we need to align our AI infrastructure with your specific operational style.", 
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onBackground.withOpacity(0.7),
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
                        subtitle: "I allow the system to analyze my usage patterns to build a custom AI model (SLM) specifically for my needs. Data is anonymized, encrypted, and strictly used to improve my results.",
                        icon: Icons.psychology_rounded,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // No-Refund Consent (Instant Compute & IP Psychology)
                      _buildConsentCard(
                        theme: theme,
                        value: _refundConsent,
                        onChanged: (val) => setState(() => _refundConsent = val ?? false),
                        title: "Instant Compute & Resource Allocation",
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
                            disabledBackgroundColor: theme.colorScheme.surfaceVariant,
                            disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
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
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      // Trust Indicator
                      Center(
                        child: Text(
                          "Bank-level AES-256 Encryption • Razorpay Secured",
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onBackground.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                          ),
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
    return Container(
      decoration: BoxDecoration(
        color: value 
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value 
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
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