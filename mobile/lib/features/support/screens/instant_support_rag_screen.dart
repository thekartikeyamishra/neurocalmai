import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InstantSupportRagScreen extends StatefulWidget {
  const InstantSupportRagScreen({super.key});

  @override
  State<InstantSupportRagScreen> createState() => _InstantSupportRagScreenState();
}

class _InstantSupportRagScreenState extends State<InstantSupportRagScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _filteredFaqs = [];

  // 🚨 COST OPTIMIZATION: Local Knowledge Base 
  // Ensures lightning-fast offline execution with zero ongoing server/LLM costs.
  final List<Map<String, String>> _knowledgeBase = [
    {
      "q": "How does NeuroCalm keep my tracking private?",
      "a": "All emotional entries and somatic health data match directly to local internal databases on your device. We use an offline-first architecture, meaning we do not transmit or store your personal journals on external cloud servers."
    },
    {
      "q": "How do I cancel my trial or subscription?",
      "a": "Subscriptions are routed securely through your native platform marketplace. You can easily manage, alter, or cancel your billing directly within your Apple App Store or Google Play Store account settings under 'Subscriptions'."
    },
    {
      "q": "Why does the app connect with Apple Health / Google Fit?",
      "a": "We correlate sleep dips and activity metrics dynamically to your baseline emotional anxiety. This allows the NeuroCalm SLM to offer automatic, context-driven parasympathetic physical regulation tools."
    },
    {
      "q": "What happens if I lose my phone?",
      "a": "Because NeuroCalm is privacy-first and offline, data lives on your device. To protect against device loss, we recommend enabling your device's native encrypted OS-level backups (iCloud or Google One) which securely back up app data."
    },
    {
      "q": "Why am I seeing ads?",
      "a": "The free tier of NeuroCalm utilizes ads to cover basic operational costs. You can instantly remove all ads and unlock advanced cognitive tools by upgrading to NeuroCalm Premium."
    }
  ];

  @override
  void initState() {
    super.initState();
    _filteredFaqs = List.from(_knowledgeBase);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runLocalSearch(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredFaqs = List.from(_knowledgeBase);
      } else {
        final lowerQuery = query.toLowerCase().trim();
        _filteredFaqs = _knowledgeBase.where((item) {
          return item['q']!.toLowerCase().contains(lowerQuery) ||
                 item['a']!.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    HapticFeedback.lightImpact();
    _searchController.clear();
    _runLocalSearch('');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Instant Support', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // 🚨 UX FIX: Automatically dismiss keyboard when scrolling through results
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Search Bar Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: TextField(
                controller: _searchController,
                onChanged: _runLocalSearch,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search for issues or keywords...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
                  prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.cancel_rounded, color: Colors.grey[400]),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.1), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.05), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 2),
                  ),
                ),
              ),
            ),
            
            // Results List Section
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _filteredFaqs.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        key: const ValueKey('results_list'),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredFaqs.length,
                        itemBuilder: (context, index) {
                          final item = _filteredFaqs[index];
                          return _buildAnimatedSupportCard(item, index, theme);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🚨 UX FIX: Staggered entrance animation for cards
  Widget _buildAnimatedSupportCard(Map<String, String> item, int index, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(item['q']),
      duration: Duration(milliseconds: 400 + (index * 100).clamp(0, 500)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02), 
              blurRadius: 15, 
              offset: const Offset(0, 8)
            )
          ],
        ),
        child: Theme(
          // Removes the ugly default borders from ExpansionTile
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const Border(), // Double safeguard against borders
            onExpansionChanged: (expanded) {
              if (expanded) HapticFeedback.selectionClick();
            },
            iconColor: theme.colorScheme.primary,
            collapsedIconColor: Colors.grey[400],
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(
              item['q']!, 
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87, height: 1.3)
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text(
                  item['a']!, 
                  style: TextStyle(color: Colors.grey[600], height: 1.6, fontSize: 14)
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  /// 🚨 UX FIX: Elegant empty state to prevent user confusion
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      key: const ValueKey('empty_state'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Answers Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Try using different keywords or simpler terms. Our offline knowledge base is designed to handle core functionality queries.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], height: 1.5, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}