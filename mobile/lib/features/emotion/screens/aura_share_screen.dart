import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/language_provider.dart';
import '../../therapy/services/openai_service.dart';
import '../services/share_service.dart';

class AuraShareScreen extends ConsumerStatefulWidget {
  final int moodScore;
  final String primaryEmotion;

  const AuraShareScreen({super.key, required this.moodScore, required this.primaryEmotion});

  @override
  ConsumerState<AuraShareScreen> createState() => _AuraShareScreenState();
}

class _AuraShareScreenState extends ConsumerState<AuraShareScreen> with SingleTickerProviderStateMixin {
  final ShareService _shareService = ShareService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  String _aiResponse = "Tuning into your frequency...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fetchAIInsight();
  }

  Future<void> _fetchAIInsight() async {
    final activeLanguage = ref.read(languageProvider);
    try {
      final aiData = await OpenAIService.instance.generateTherapyResponse(
        "My facial scan shows I am feeling ${widget.primaryEmotion}.", 
        [], 
        activeLanguage.displayName
      );
      if (mounted) {
        setState(() {
          _aiResponse = aiData['reply'] ?? "Take a deep breath. You are doing great.";
          _isLoading = false;
        });
        _fadeController.forward();
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResponse = "Take a deep breath. I am here for you.";
          _isLoading = false;
        });
        _fadeController.forward();
      }
    }
  }

  List<Color> _getAuraGradient() {
    if (widget.moodScore <= 3) return [const Color(0xFFEF4444), const Color(0xFFF59E0B)]; // Warm, Stressed
    if (widget.moodScore <= 6) return [const Color(0xFF8B5CF6), const Color(0xFF6366F1)]; // Neutral, Focused
    return [const Color(0xFF10B981), const Color(0xFF3B82F6)]; // Cool, Calm
  }

  Widget _buildAuraCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(colors: _getAuraGradient(), begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(color: _getAuraGradient()[0].withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.blur_on_rounded, color: Colors.white, size: 64),
          const SizedBox(height: 24),
          Text(
            "My Current Aura",
            style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            widget.primaryEmotion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.colorScheme.primary),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildAuraCard(),
              const SizedBox(height: 32),
              
              TextButton.icon(
                onPressed: () => _shareService.shareAura(context, _buildAuraCard()),
                icon: Icon(Icons.ios_share_rounded, color: theme.colorScheme.primary),
                label: Text("Share My Aura", style: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),

              const Spacer(),
              
              _isLoading 
                ? CircularProgressIndicator(color: theme.colorScheme.primary)
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 4))],
                      ),
                      child: Text(
                        '"$_aiResponse"',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.w500, color: Colors.grey[800], fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}