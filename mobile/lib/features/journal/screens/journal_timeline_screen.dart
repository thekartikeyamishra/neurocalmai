import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🚨 NEW
import 'package:intl/intl.dart';

import '../services/local_journal_service.dart';
import '../../monetization/screens/insight_reward_screen.dart';
import '../../monetization/widgets/smart_banner_card.dart';

// 🚨 ARCHITECT FIX: Converted to ConsumerWidget to react instantly to database changes
class JournalTimelineScreen extends ConsumerWidget {
  const JournalTimelineScreen({super.key});

  Color _getEmotionColor(String emotion) {
    final em = emotion.toLowerCase();
    if (em.contains('anxi') || em.contains('stress') || em.contains('ang') || em.contains('distress')) {
      return const Color(0xFFE6A822); 
    } else if (em.contains('calm') || em.contains('happy') || em.contains('neutral') || em.contains('focus')) {
      return const Color(0xFF2A5C5A); 
    } else if (em.contains('sad') || em.contains('fatigue') || em.contains('lethargic')) {
      return const Color(0xFF64748B); 
    }
    return const Color(0xFF38BDF8); 
  }

  // 🚨 UI FIX: Added dedicated visual cue for Health Data syncing
  IconData _getSessionIcon(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType == 'text') return Icons.edit_note_rounded;
    if (lowerType == 'voice') return Icons.mic_rounded;
    if (lowerType == 'scan') return Icons.face_retouching_natural_rounded;
    if (lowerType.contains('health') || lowerType.contains('sync')) return Icons.monitor_heart_rounded;
    return Icons.auto_awesome_rounded;
  }

  void _handleEntryTap(BuildContext context, JournalEntry entry) {
    HapticFeedback.selectionClick();

    if (entry.slmFeaturesJson != null && entry.slmFeaturesJson!.isNotEmpty) {
      try {
        final Map<String, dynamic> slmFeatures = jsonDecode(entry.slmFeaturesJson!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InsightRewardScreen(slmFeatures: slmFeatures),
          ),
        );
      } catch (e) {
        debugPrint('[JournalTimeline Error]: Failed to decode SLM JSON - $e');
        _showSnackBar(context, 'Insight data is corrupted and cannot be read.');
      }
    } else {
      _showSnackBar(context, 'Deep insights are not available for this older entry.');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // 🚨 REACTIVE STATE: Listens to the SQLite engine in real-time
    final asyncEntries = ref.watch(journalTimelineProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      bottomNavigationBar: const SmartBannerCard(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.primary),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'My Journey', 
          style: TextStyle(
            color: theme.colorScheme.primary, 
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.primary),
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(journalTimelineProvider.notifier).refresh();
            },
          )
        ],
      ),
      body: SafeArea(
        child: asyncEntries.when(
          loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary, strokeWidth: 2)),
          error: (err, stack) => Center(child: Text('Error loading journal: $err')),
          data: (entries) {
            if (entries.isEmpty) return _buildEmptyState(theme);

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 16, bottom: 40, right: 24),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isLast = index == entries.length - 1;
                return _buildTimelineItem(context, entry, theme, index, isLast);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_stories_rounded, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              'Your journal is clear.',
              textAlign: TextAlign.center,
              style: theme.textTheme.displayLarge?.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 12),
            Text(
              'Complete a text, voice, or scanning session. Your insights will automatically be saved here, securely and offline.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, JournalEntry entry, ThemeData theme, int index, bool isLast) {
    final date = DateTime.parse(entry.date);
    final color = _getEmotionColor(entry.emotion);
    final hasInsights = entry.slmFeaturesJson != null && entry.slmFeaturesJson!.isNotEmpty;
    
    final animationDelay = (index * 150).clamp(0, 900);

    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        final double opacity = (value - (animationDelay / 2000)).clamp(0.0, 1.0);
        
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LEFT COLUMN: The Timeline Stem & Node
                  SizedBox(
                    width: 60,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        if (!isLast)
                          Positioned(
                            top: 40,
                            bottom: 0,
                            child: Container(
                              width: 2,
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                        Positioned(
                          top: 16,
                          child: Container(
                            height: 24,
                            width: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                height: 8,
                                width: 8,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // RIGHT COLUMN: The Insight Card
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: hasInsights ? theme.colorScheme.primary.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.15),
                            width: hasInsights ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          clipBehavior: Clip.antiAlias, 
                          child: InkWell(
                            onTap: () => _handleEntryTap(context, entry),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          DateFormat('EEEE, MMM d • h:mm a').format(date.toLocal()),
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(_getSessionIcon(entry.sessionType), size: 14, color: color),
                                            const SizedBox(width: 4),
                                            Text(
                                              entry.sessionType.toUpperCase(),
                                              style: TextStyle(
                                                color: color,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    entry.aiInsight,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Icon(Icons.psychology_rounded, size: 16, color: color),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Detected state: ',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                      ),
                                      Text(
                                        entry.emotion,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (hasInsights)
                                        Row(
                                          children: [
                                            Text(
                                              'Analyze',
                                              style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.lock_outline_rounded, size: 14, color: theme.colorScheme.primary),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}