import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A production-ready localized community feed.
/// Renders a geofenced "Grounding Circle" where users can share CBT milestones.
/// To ensure absolute safety and prevent toxicity, free-text input is disabled.
/// Interaction is strictly limited to predefined milestone templates and emoji reactions.
class LocalHubScreen extends StatefulWidget {
  final String locationName;

  const LocalHubScreen({
    super.key, 
    this.locationName = 'Prayagraj Grounding Circle', // Defaults to local geofenced hub
  });

  @override
  State<LocalHubScreen> createState() => _LocalHubScreenState();
}

class _LocalHubScreenState extends State<LocalHubScreen> {
  static const Color _primaryGreen = Color(0xFF1E3A2F);
  static const Color _accentGreen = Color(0xFF2E6F56);
  static const Color _surfaceColor = Color(0xFFF9FAF9);

  // Mocked state for local milestones to demonstrate the UI structure.
  // In production, this would be a StreamBuilder listening to Firestore.
  final List<_MilestoneEvent> _feed = [
    _MilestoneEvent(
      id: '1',
      avatarIcon: Icons.psychology_rounded,
      avatarColor: Colors.teal.shade200,
      milestoneTitle: 'Completed a 7-Day CBT Streak',
      timestamp: '2 mins ago',
      reactions: {'👏': 12, '💚': 5, '🧘‍♀️': 3},
    ),
    _MilestoneEvent(
      id: '2',
      avatarIcon: Icons.water_drop_rounded,
      avatarColor: Colors.blue.shade200,
      milestoneTitle: 'Mastered the 4-7-8 Deep Pacing Rhythm',
      timestamp: '15 mins ago',
      reactions: {'👏': 8, '💚': 14, '🧘‍♀️': 0},
    ),
    _MilestoneEvent(
      id: '3',
      avatarIcon: Icons.spa_rounded,
      avatarColor: Colors.orange.shade200,
      milestoneTitle: 'Logged a Cognitive Reframe',
      timestamp: '1 hour ago',
      reactions: {'👏': 45, '💚': 22, '🧘‍♀️': 18},
    ),
  ];

  void _handleReaction(String eventId, String emoji) {
    HapticFeedback.lightImpact();
    setState(() {
      final eventIndex = _feed.indexWhere((e) => e.id == eventId);
      if (eventIndex != -1) {
        final currentCount = _feed[eventIndex].reactions[emoji] ?? 0;
        _feed[eventIndex].reactions[emoji] = currentCount + 1;
      }
    });
  }

  void _shareMilestone() {
    HapticFeedback.mediumImpact();
    // In production, this opens a bottom sheet to select a predefined milestone
    // template (e.g., "Share Streak", "Share Breathing Session") rather than a text keyboard.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Milestone template selector will open here.'),
        backgroundColor: _accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.locationName,
              style: const TextStyle(
                color: _primaryGreen,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '142 members nearby',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          ],
        ),
        iconTheme: const IconThemeData(color: _primaryGreen),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16.0),
          itemCount: _feed.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final event = _feed[index];
            return _buildMilestoneCard(event);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _shareMilestone,
        backgroundColor: _accentGreen,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Share Progress',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneCard(_MilestoneEvent event) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: event.avatarColor.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: Icon(event.avatarIcon, color: event.avatarColor.withAlpha(200), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Anonymous Member',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primaryGreen,
                      ),
                    ),
                    Text(
                      event.timestamp,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz_rounded, color: Colors.grey.shade400, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            event.milestoneTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _primaryGreen,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 12),
          Row(
            children: event.reactions.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: () => _handleReaction(event.id, entry.key),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entry.key, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          entry.value.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Internal model representing a community milestone.
class _MilestoneEvent {
  final String id;
  final IconData avatarIcon;
  final Color avatarColor;
  final String milestoneTitle;
  final String timestamp;
  final Map<String, int> reactions;

  _MilestoneEvent({
    required this.id,
    required this.avatarIcon,
    required this.avatarColor,
    required this.milestoneTitle,
    required this.timestamp,
    required this.reactions,
  });
}