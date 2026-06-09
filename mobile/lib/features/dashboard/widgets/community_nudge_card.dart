import 'package:flutter/material.dart';
import '../../growth/screens/offline_waitlist_screen.dart';

class CommunityNudgeCard extends StatefulWidget {
  final String userCity;
  final int localWaitlistCount;
  final VoidCallback? onDismiss;

  const CommunityNudgeCard({
    Key? key,
    required this.userCity,
    required this.localWaitlistCount,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<CommunityNudgeCard> createState() => _CommunityNudgeCardState();
}

class _CommunityNudgeCardState extends State<CommunityNudgeCard> 
    with SingleTickerProviderStateMixin {
  
  bool _isVisible = true;

  void _handleDismiss() {
    setState(() {
      _isVisible = false;
    });
    // Trigger callback to save dismissal state in SharedPreferences/Firestore
    // so the user isn't annoyed by seeing this on every app launch.
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  void _navigateToWaitlist() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OfflineWaitlistScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    
    // Psychological Nudge: Social Proof + FOMO
    // If numbers are too low, using "Several" prevents the "Empty Restaurant" syndrome.
    final displayCount = widget.localWaitlistCount >= 10 
        ? '${widget.localWaitlistCount}' 
        : 'Several';

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        color: theme.colorScheme.primaryContainer.withOpacity(0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_alt_rounded, 
                        color: theme.colorScheme.primary,
                        size: 28,
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
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$displayCount people in ${widget.userCity} are waiting for local offline chapters. Claim your founding spot.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Action Indicator
                    Icon(
                      Icons.arrow_forward_ios_rounded, 
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
              
              // Dismiss Button (Prevents Nudge Fatigue / Churn)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.5),
                  tooltip: 'Dismiss',
                  onPressed: _handleDismiss,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}