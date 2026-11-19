import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/secure_ai_gateway.dart';
import '../../../core/theme/app_tokens.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../journal/services/local_journal_service.dart';

/// The "aha in under 20 seconds" first-run flow.
///
/// Old first run: splash (2.8s) -> 3+ onboarding pages -> sign-in screen ->
/// tools list. No value was felt before the user had to decide whether to
/// stay. New first run: one tap on what's weighing on you (or one line of
/// text) -> a personal CBT reframe + a 60-second action -> saved as your
/// first journal entry. Works offline (local reframe library) so the first
/// emotion is always relief, never an error.
class FirstWinScreen extends StatefulWidget {
  /// When opened from the dashboard (welcome-back), pop instead of replacing.
  final bool returnOnFinish;
  const FirstWinScreen({super.key, this.returnOnFinish = false});

  @override
  State<FirstWinScreen> createState() => _FirstWinScreenState();
}

class _Starter {
  final String label;
  final IconData icon;
  final String thought;
  final String distortion;
  final String reframe;
  final String action;
  const _Starter(this.label, this.icon, this.thought, this.distortion, this.reframe, this.action);
}

const _starters = <_Starter>[
  _Starter('Work or exams', Icons.work_outline_rounded,
      "I'm going to mess this up and everyone will see I'm not good enough.",
      'Fortune telling',
      "Your mind is predicting failure as if it already happened. Pressure means this matters to you — and you've handled hard things before.",
      'Write down the one smallest next step and do only that for 10 minutes.'),
  _Starter('Overthinking', Icons.autorenew_rounded,
      "I keep replaying everything and I can't switch my brain off.",
      'Rumination',
      "Replaying feels like problem-solving, but it's your brain looking for safety. You can park the thought and come back to it on purpose.",
      'Set a 2-minute timer, write every looping thought down, then close the note.'),
  _Starter("Can't sleep", Icons.nights_stay_outlined,
      "If I don't sleep now, tomorrow will be a disaster.",
      'Catastrophizing',
      "One rough night feels huge at 2 a.m., but your body is good at recovering. Resting quietly still counts.",
      'Breathe in for 4, out for 6, five times. Let the pillow hold your head.'),
  _Starter('People & relationships', Icons.people_outline_rounded,
      "They didn't reply — they must be upset with me.",
      'Mind reading',
      "You're filling a silence with the worst explanation. There are many reasons people don't reply, and most aren't about you.",
      'List two other possible reasons for the silence before deciding how to feel.'),
];

class _FirstWinScreenState extends State<FirstWinScreen> {
  final TextEditingController _controller = TextEditingController();
  _Starter? _picked;
  bool _loading = false;
  Map<String, String>? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _untangle() async {
    final typed = _controller.text.trim();
    final starter = _picked;
    if (typed.isEmpty && starter == null) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final thought = typed.isNotEmpty ? typed : starter!.thought;
    Map<String, String> result;
    try {
      final data = await SecureAIGateway()
          .generateCBTReframe(userText: thought)
          .timeout(const Duration(seconds: 9));
      result = {
        'distortion': (data['distortion'] ?? 'none').toString(),
        'reframe': (data['reframe'] ?? '').toString(),
        'action': (data['action'] ?? '').toString(),
      };
      if (result['reframe']!.isEmpty) throw Exception('empty');
    } catch (_) {
      final s = starter ?? _starters[1];
      result = {'distortion': s.distortion, 'reframe': s.reframe, 'action': s.action};
    }

    unawaited(_saveFirstEntry(thought, result));
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  Future<void> _saveFirstEntry(String thought, Map<String, String> r) async {
    try {
      await LocalJournalService.instance.saveEntry(JournalEntry(
        date: DateTime.now().toIso8601String(),
        sessionType: 'First Reframe',
        emotion: r['distortion'] ?? 'none',
        aiInsight: '${r['reframe']}\n\nNext step: ${r['action']}',
        slmFeaturesJson: jsonEncode({'thought_length': thought.length, 'source': 'first_win'}),
      ));
    } catch (_) {}
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    await prefs.setInt('total_investments', (prefs.getInt('total_investments') ?? 0) + 1);
    if (!mounted) return;
    if (widget.returnOnFinish) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const DashboardScreen(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: _result == null ? _buildAsk() : _buildResult(_result!),
        ),
      ),
    );
  }

  Widget _buildAsk() {
    final canGo = _picked != null || _controller.text.trim().isNotEmpty;
    return ListView(
      key: const ValueKey('ask'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const Text("What's weighing on you right now?",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.15, color: AppTokens.onSurface)),
        const SizedBox(height: 10),
        const Text('Pick one or type a line. You\'ll get a calmer way to see it in seconds.',
            style: TextStyle(fontSize: 15, height: 1.45, color: AppTokens.onSurfaceVariant)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _starters.map((s) {
            final selected = identical(_picked, s);
            return ChoiceChip(
              avatar: Icon(s.icon, size: 18, color: selected ? Colors.white : AppTokens.primary),
              label: Text(s.label),
              selected: selected,
              selectedColor: AppTokens.primary,
              labelStyle: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : AppTokens.onSurface),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _picked = selected ? null : s);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          maxLength: 280,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Or in your words… (Hindi or English is fine)',
            filled: true,
            fillColor: AppTokens.surfaceContainer,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: canGo && !_loading ? _untangle : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
            ),
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Untangle this thought', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: AppTokens.onSurfaceVariant),
            SizedBox(width: 6),
            Flexible(
              child: Text('No sign-up. Your journal stays on this phone.',
                  style: TextStyle(fontSize: 12.5, color: AppTokens.onSurfaceVariant)),
            ),
          ],
        ),
        TextButton(onPressed: _finish, child: const Text('Skip for now')),
      ],
    );
  }

  Widget _buildResult(Map<String, String> r) {
    final distortion = r['distortion'] ?? 'none';
    return ListView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const Icon(Icons.spa_rounded, color: AppTokens.primary, size: 40),
        const SizedBox(height: 12),
        const Text('Here\'s a calmer way to see it',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTokens.onSurface)),
        const SizedBox(height: 18),
        if (distortion.toLowerCase() != 'none')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppTokens.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
            child: Text('Thinking trap spotted: $distortion',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF9A5B2A))),
          ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppTokens.surfaceContainer, borderRadius: BorderRadius.circular(20)),
          child: Text(r['reframe'] ?? '', style: const TextStyle(fontSize: 17, height: 1.5, color: AppTokens.onSurface)),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppTokens.primaryContainer, borderRadius: BorderRadius.circular(20)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt_rounded, color: AppTokens.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('Your next 60 seconds: ${r['action']}',
                  style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w600, color: AppTokens.primary))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text('Saved as your first private journal entry.',
            style: TextStyle(fontSize: 12.5, color: AppTokens.onSurfaceVariant)),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
            ),
            child: const Text('That helped — continue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}
