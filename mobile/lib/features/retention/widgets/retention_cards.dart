import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_tokens.dart';
import '../../journal/screens/cbt_wizard_screen.dart';
import '../../journal/screens/guided_task_screen.dart';
import '../../journal/screens/sleep_dump_screen.dart';
import '../../journal/screens/standard_journal_screen.dart';
import '../../journal/services/local_journal_service.dart';
import '../../onboarding/presentation/first_win_screen.dart';
import '../services/reengagement_service.dart';

/// One card at the top of the dashboard, chosen by priority:
/// 1) an unfinished reflection (resume), 2) a returning user (welcome back).
/// Shows nothing for everyday users, so it never becomes noise.
class ReturnCard extends StatefulWidget {
  const ReturnCard({super.key});

  @override
  State<ReturnCard> createState() => _ReturnCardState();
}

class _ReturnCardState extends State<ReturnCard> {
  String? _flow;
  bool _loaded = false;
  bool _dismissed = false;

  static const Map<String, String> _labels = {
    'cbt_wizard': 'CBT reframe',
    'standard_journal': 'daily reflection',
    'sleep_dump': 'sleep brain-dump',
    'guided_task': 'task unblock',
  };

  @override
  void initState() {
    super.initState();
    ReengagementService.instance
        .start()
        .then((_) => ReengagementService.instance.unfinishedFlow())
        .then((f) {
      if (mounted) setState(() {
        _flow = f;
        _loaded = true;
      });
    });
  }

  Widget _screenFor(String flow) {
    switch (flow) {
      case 'cbt_wizard':
        return const CbtWizardScreen();
      case 'sleep_dump':
        return const SleepDumpScreen();
      case 'guided_task':
        return const GuidedTaskScreen();
      default:
        return const StandardJournalScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _dismissed) return const SizedBox.shrink();
    final flow = _flow;
    final away = ReengagementService.instance.daysAway;

    if (flow != null) {
      return _card(
        icon: Icons.play_circle_outline_rounded,
        title: 'Finish your ${_labels[flow] ?? 'reflection'}?',
        body: 'You started one but didn\'t save it. It takes about a minute.',
        cta: 'Continue',
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(context, MaterialPageRoute(builder: (_) => _screenFor(flow)));
        },
        onClose: () {
          ReengagementService.instance.dismissUnfinished();
          setState(() => _dismissed = true);
        },
      );
    }
    if (away >= 3) {
      return _card(
        icon: Icons.waving_hand_outlined,
        title: 'Welcome back',
        body: 'No catching up needed. Start with one 60-second reflection.',
        cta: 'Start',
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FirstWinScreen(returnOnFinish: true)));
        },
        onClose: () => setState(() => _dismissed = true),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String body,
    required String cta,
    required VoidCallback onTap,
    required VoidCallback onClose,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spacing24),
      padding: const EdgeInsets.all(AppTokens.spacing16),
      decoration: BoxDecoration(
        color: AppTokens.primaryContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTokens.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTokens.onSurface)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 13, color: AppTokens.onSurfaceVariant)),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: Text(cta, style: const TextStyle(fontWeight: FontWeight.w800))),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 18, color: AppTokens.onSurfaceVariant),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Weekly Pattern Report — the top-1% retention feature. Computed entirely on
/// the device from the local journal (no AI cost, no data leaves the phone):
/// how many reflections this week, the most frequent thinking trap / feeling,
/// and a share-safe line that contains no journal text.
class PatternReportCard extends StatefulWidget {
  const PatternReportCard({super.key});

  @override
  State<PatternReportCard> createState() => _PatternReportCardState();
}

class _PatternReportCardState extends State<PatternReportCard> {
  int _count = 0;
  String? _topLabel;
  int _topCount = 0;
  bool _loaded = false;

  static const _ignore = {'none', 'neutral', 'reflection', 'racing_thoughts', ''};

  @override
  void initState() {
    super.initState();
    _compute();
  }

  String _pretty(String raw) {
    final t = raw.replaceAll('_', ' ').trim();
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }

  Future<void> _compute() async {
    final entries = await LocalJournalService.instance.fetchHistory();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final counts = <String, int>{};
    var n = 0;
    for (final e in entries) {
      final at = DateTime.tryParse(e.date);
      if (at == null || at.isBefore(cutoff)) continue;
      n++;
      final key = e.emotion.trim().toLowerCase();
      if (_ignore.contains(key)) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    String? top;
    var topN = 0;
    counts.forEach((k, v) {
      if (v > topN) {
        top = k;
        topN = v;
      }
    });
    if (!mounted) return;
    setState(() {
      _count = n;
      _topLabel = top == null ? null : _pretty(top!);
      _topCount = topN;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _count < 2) return const SizedBox.shrink();
    final top = _topLabel;
    return Container(
      margin: const EdgeInsets.only(top: AppTokens.spacing24),
      padding: const EdgeInsets.all(AppTokens.spacing16),
      decoration: BoxDecoration(
        color: AppTokens.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: AppTokens.onSurfaceVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, color: AppTokens.primary, size: 20),
              SizedBox(width: 8),
              Text('Your week in patterns',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTokens.onSurface)),
            ],
          ),
          const SizedBox(height: 10),
          Text('$_count reflections in the last 7 days.',
              style: const TextStyle(fontSize: 14, color: AppTokens.onSurface)),
          if (top != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Most frequent: $top ($_topCount×). Noticing it is the first step to loosening it.',
                  style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppTokens.onSurfaceVariant)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Share my week'),
              onPressed: () => SharePlus.instance.share(ShareParams(
                text: 'I did $_count calm reflections this week with NeuroCalm. '
                    'One minute a day to untangle anxious thoughts — privately.\n'
                    'https://play.google.com/store/apps/details?id=com.kartikeyamishra.mobile',
              )),
            ),
          ),
        ],
      ),
    );
  }
}
