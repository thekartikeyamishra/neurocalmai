import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../monetization/services/admob_service.dart';
import '../../monetization/widgets/smart_banner_card.dart';
import '../../monetization/services/subscription_service.dart'; 
import '../providers/streak_provider.dart';

class HabitCalendarScreen extends ConsumerStatefulWidget {
  const HabitCalendarScreen({super.key});

  @override
  ConsumerState<HabitCalendarScreen> createState() => _HabitCalendarScreenState();
}

class _HabitCalendarScreenState extends ConsumerState<HabitCalendarScreen> {
  late PageController _pageController;
  DateTime _currentMonth = DateTime.now();

  // Psychological Palette: Shifts per month to minimize user visual fatigue
  final List<Color> _monthColors = [
    const Color(0xFF2A5C5A), const Color(0xFF3B5998), const Color(0xFF5A3B5D),
    const Color(0xFF2E6F40), const Color(0xFF8B5A2B), const Color(0xFFD2691E),
    const Color(0xFFCD5C5C), const Color(0xFF4682B4), const Color(0xFF6B8E23),
    const Color(0xFF8B4513), const Color(0xFF483D8B), const Color(0xFF2F4F4F),
  ];

  @override
  void initState() {
    super.initState();
    // Centered pivot index provides smooth infinite directional scrolling feel
    _pageController = PageController(initialPage: 1200);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _triggerHaptic() => HapticFeedback.lightImpact();

  void _onPageChanged(int index) {
    _triggerHaptic();
    setState(() {
      int offset = index - 1200;
      _currentMonth = DateTime(DateTime.now().year, DateTime.now().month + offset, 1);
    });
  }

  /// Handles systemic view pops while processing interstitial ads for ad-supported profiles
  void _handleExit() {
    _triggerHaptic();
    
    final isPremium = ref.read(subscriptionProvider).isPremium;
    if (!isPremium) {
      AdMobService.instance.showInterstitialAdIfAppropriate(placement: 'calendar_exit');
    }
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final asyncStreak = ref.watch(streakProvider);
    final activeColor = _monthColors[_currentMonth.month - 1];
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExit();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        bottomNavigationBar: const SmartBannerCard(),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: activeColor),
            onPressed: _handleExit,
          ),
          title: Text(
            'Consistency',
            style: TextStyle(
              color: activeColor, 
              fontWeight: FontWeight.w900, 
              letterSpacing: -0.5,
              fontFamily: 'Inter',
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: asyncStreak.when(
            loading: () => Center(child: CircularProgressIndicator(color: activeColor, strokeWidth: 3)),
            error: (err, stack) => Center(
              child: Text(
                'Error loading database logs: $err',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            data: (streakState) {
              return Column(
                children: [
                  // --- STREAK HERO CARD ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [activeColor, activeColor.withValues(alpha: 0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Streak', 
                                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${streakState.currentStreak} Days', 
                                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              ),
                            ],
                          ),
                          const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 56),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // --- INFINITE CALENDAR SLIDER ---
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        int offset = index - 1200;
                        DateTime displayMonth = DateTime(DateTime.now().year, DateTime.now().month + offset, 1);
                        return _buildCalendarGrid(displayMonth, activeColor, streakState.completedDates);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(DateTime month, Color activeColor, Set<String> completedDates) {
    int daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    DateTime firstDay = DateTime(month.year, month.month, 1);
    
    // Shift index matrix cleanly to evaluate Monday as standard index position 0
    int firstWeekday = firstDay.weekday; // 1 (Mon) to 7 (Sun)

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: activeColor, letterSpacing: -0.3),
          ),
          const SizedBox(height: 28),
          
          // Unified Row Weekday Identifiers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((day) => Expanded(
                      child: Text(
                        day, 
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          // Core Day Alignment Grid Matrix
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: daysInMonth + firstWeekday - 1,
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) return const SizedBox.shrink();
                
                int dayNumber = index - firstWeekday + 2;
                DateTime thisDate = DateTime(month.year, month.month, dayNumber);
                
                String dateKey = DateFormat('yyyy-MM-dd').format(thisDate);
                bool isCompleted = completedDates.contains(dateKey);
                
                bool isToday = thisDate.year == DateTime.now().year && 
                               thisDate.month == DateTime.now().month && 
                               thisDate.day == DateTime.now().day;

                return TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 450),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: isCompleted ? (0.3 + (value * 0.7)) : 1.0, 
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCompleted ? activeColor : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isToday ? activeColor : (isCompleted ? activeColor : Colors.grey[200]!),
                            width: isToday ? 2.5 : 1.0,
                          ),
                          boxShadow: isCompleted ? [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.25), 
                              blurRadius: 8, 
                              offset: const Offset(0, 3),
                            )
                          ] : [],
                        ),
                        child: Center(
                          child: Text(
                            dayNumber.toString(),
                            style: TextStyle(
                              color: isCompleted ? Colors.white : (isToday ? activeColor : Colors.grey[800]),
                              fontWeight: isToday || isCompleted ? FontWeight.w900 : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}