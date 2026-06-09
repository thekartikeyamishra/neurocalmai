import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../growth/screens/offline_waitlist_screen.dart';

class CommunityNudgeCard extends StatefulWidget {
  final String userCity;
  final int localWaitlistCount;
  final VoidCallback? onDismiss;

  const CommunityNudgeCard({
    super.key,
    required this.userCity,
    required this.localWaitlistCount,
    this.onDismiss,
  });

  @override
  State<CommunityNudgeCard> createState() => _CommunityNudgeCardState();
}

class _CommunityNudgeCardState extends State<CommunityNudgeCard> 
    with SingleTickerProviderStateMixin {
  
  bool _isVisible = true;

  void _handleDismiss() {
    HapticFeedback.lightImpact();
    setState(() {
      _isVisible = false;
    });
    // Trigger callback to save dismissal state in SharedPreferences/Firestore
    // so the user isn't annoyed by seeing this on every app launch, protecting retention.
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  void _navigateToWaitlist() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OfflineWaitlistScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fast exit if dismissed
    if (!_isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    
    // Psychological Nudge: Social Proof + FOMO
    // If numbers are too low, using "Several" prevents the "Empty Restaurant" syndrome.
    final displayCount = widget.localWaitlistCount >= 10 
        ? '${widget.localWaitlistCount}' 
        : 'Several';

    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _navigateToWaitlist,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Visual Anchor
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.people_alt_rounded, 
                          color: theme.colorScheme.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Copy & Nudge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Craving human connection?',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$displayCount people in ${widget.userCity} are waiting for local offline chapters. Claim your founding spot.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Action Indicator
                      Icon(
                        Icons.arrow_forward_ios_rounded, 
                        size: 16,
                        color: theme.colorScheme.primary.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
                
                // Dismiss Button (Prevents Nudge Fatigue / Churn)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.4),
                    splashRadius: 20,
                    tooltip: 'Dismiss',
                    onPressed: _handleDismiss,
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