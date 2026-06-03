import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../settings/providers/sensory_provider.dart';
import '../../settings/providers/language_provider.dart'; // 🚨 NEW IMPORT: Localization Engine

class SleepModeScreen extends ConsumerStatefulWidget {
  const SleepModeScreen({super.key});

  @override
  ConsumerState<SleepModeScreen> createState() => _SleepModeScreenState();
}

class _SleepModeScreenState extends ConsumerState<SleepModeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  late FlutterTts _tts;

  int _currentStep = 0;
  bool _isAnimating = false;

  // 🚨 ARCHITECT FIX: Fully Localized Offline Sleep Scripts
  // cSpell:disable
  final Map<String, List<String>> _localL10n = {
    'en-IN': [
      "Welcome to Sleep Mode. Let's wind down.",
      "Close your eyes. Take a slow, deep breath in...",
      "...and let it out softly.",
      "Focus on your toes. Tense them slightly...",
      "...and completely release.",
      "Move up to your legs. Notice any tension...",
      "...and let it melt away into the bed.",
      "Your body is becoming heavy and relaxed.",
      "Your mind is quiet. You are safe.",
      "Drift off whenever you are ready. Goodnight.",
    ],
    'hi-IN': [
      "स्लीप मोड में आपका स्वागत है। चलिए आराम करते हैं।",
      "अपनी आँखें बंद करें। एक लंबी, गहरी सांस लें...",
      "...और इसे धीरे से छोड़ दें।",
      "अपने पैर की उंगलियों पर ध्यान दें। उन्हें थोड़ा कस लें...",
      "...और पूरी तरह से ढीला छोड़ दें।",
      "अपने पैरों की ओर बढ़ें। किसी भी तनाव पर ध्यान दें...",
      "...और उसे बिस्तर में पिघल जाने दें।",
      "आपका शरीर भारी और शांत हो रहा है।",
      "आपका मन शांत है। आप सुरक्षित हैं।",
      "जब भी आप तैयार हों, सो जाएं। शुभ रात्रि।",
    ],
    'ta-IN': [
      "ஸ்லீப் மோடிற்கு வருக. நாம் ஓய்வெடுப்போம்.",
      "உங்கள் கண்களை மூடுங்கள். மெதுவாக, ஆழமாக மூச்சு இழுக்கவும்...",
      "...பின்னர் மெதுவாக வெளியிடவும்.",
      "உங்கள் கால் விரல்களில் கவனம் செலுத்துங்கள். அவற்றை சிறிது இறுக்குங்கள்...",
      "...பின்னர் முழுமையாக தளர்த்துங்கள்.",
      "உங்கள் கால்களுக்கு முன்னேறுங்கள். ஏதேனும் பதற்றம் இருக்கிறதா என்று கவனியுங்கள்...",
      "...அதை படுக்கையில் கரைய விடுங்கள்.",
      "உங்கள் உடல் கனமாகவும் தளர்வாகவும் மாறுகிறது.",
      "உங்கள் மனம் அமைதியாக இருக்கிறது. நீங்கள் பாதுகாப்பாக உள்ளீர்கள்.",
      "நீங்கள் தயாரானதும் தூங்குங்கள். இனிய இரவு.",
    ],
    'mr-IN': [
      "स्लीप मोडमध्ये आपले स्वागत आहे. चला विश्रांती घेऊया.",
      "तुमचे डोळे मिटा. एक संथ, दीर्घ श्वास घ्या...",
      "...आणि हळूवारपणे सोडून द्या.",
      "तुमच्या पायाच्या बोटांवर लक्ष केंद्रित करा. त्यांना थोडे घट्ट करा...",
      "...आणि पूर्णपणे सोडून द्या.",
      "तुमच्या पायांकडे वळा. कोणताही ताण लक्षात घ्या...",
      "...आणि तो गादीत विरघळू द्या.",
      "तुमचे शरीर जड आणि शांत होत आहे.",
      "तुमचे मन शांत आहे. तुम्ही सुरक्षित आहात.",
      "जेव्हा तुम्ही तयार असाल तेव्हा झोपा. शुभ रात्री.",
    ],
    'bn-IN': [
      "স্লিপ মোডে স্বাগতম। চলুন বিশ্রাম নিই।",
      "আপনার চোখ বন্ধ করুন। ধীরে ধীরে একটি গভীর শ্বাস নিন...",
      "...এবং এটি আলতো করে ছেড়ে দিন।",
      "আপনার পায়ের আঙ্গুলের দিকে মনোযোগ দিন। সেগুলোকে সামান্য শক্ত করুন...",
      "...এবং পুরোপুরি ছেড়ে দিন।",
      "আপনার পায়ের দিকে যান। কোন উত্তেজনা লক্ষ্য করুন...",
      "...এবং এটি বিছানায় গলে যেতে দিন।",
      "আপনার শরীর ভারী এবং শিথিল হয়ে উঠছে।",
      "আপনার মন শান্ত। আপনি নিরাপদ।",
      "যখনই আপনি প্রস্তুত, ঘুমিয়ে পড়ুন। শুভ রাত্রি।",
    ],
    'te-IN': [
      "స్లీప్ మోడ్‌కు స్వాగతం. విశ్రాంతి తీసుకుందాం.",
      "మీ కళ్ళు మూసుకోండి. నెమ్మదిగా, దీర్ఘంగా గాలి పీల్చండి...",
      "...మరియు మెల్లగా వదలండి.",
      "మీ కాలి వేళ్లపై దృష్టి పెట్టండి. వాటిని కొద్దిగా బిగించండి...",
      "...మరియు పూర్తిగా వదిలేయండి.",
      "మీ కాళ్ళ వైపు కదలండి. ఏదైనా ఉద్రిక్తత ఉంటే గమనించండి...",
      "...అది మంచంలో కరిగిపోనివ్వండి.",
      "మీ శరీరం బరువుగా మరియు రిలాక్స్‌గా మారుతోంది.",
      "మీ మనస్సు ప్రశాంతంగా ఉంది. మీరు సురక్షితంగా ఉన్నారు.",
      "మీరు సిద్ధంగా ఉన్నప్పుడు నిద్రపోండి. శుభరాత్రి.",
    ],
  };
  // cSpell:enable

  // Colors engineered to eliminate blue light (Melatonin-safe)
  final Color _pureBlack = const Color(0xFF000000);
  final Color _warmAmberText = const Color(0xFFD9A071);
  final Color _deepWarmGlow = const Color(0xFF8B3A00);

  @override
  void initState() {
    super.initState();

    // 1. Text Fading Animation (Slow & Gentle)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
      reverseDuration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // 2. Hypnotic Breathing Animation (Ultra-Slow Parasympathetic Entrainment)
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6), // 6s inhale, 6s exhale (12s total cycle)
    );

    _breathAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    // 3. Base Audio Initialization
    _tts = FlutterTts();
    _tts.setSpeechRate(0.35); // Extremely slow for sleep induction
    _tts.setPitch(0.75); // Deep, soothing pitch
    _tts.awaitSpeakCompletion(true);

    // Start lifecycle
    _breathController.repeat(reverse: true);
    
    // We defer the start to safely read the global Language Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialAnimation();
    });
  }

  Future<void> _startInitialAnimation() async {
    setState(() => _isAnimating = true);
    await _fadeController.forward();
    if (mounted) {
      setState(() => _isAnimating = false);
      _handleVoiceGuidance();
    }
  }

  Future<void> _handleVoiceGuidance() async {
    final isVoiceEnabled = ref.read(sensoryProvider).voiceGuidanceEnabled;
    final activeDialect = ref.read(languageProvider);
    final scriptList = _localL10n[activeDialect.code] ?? _localL10n['en-IN']!;

    if (isVoiceEnabled && _currentStep < scriptList.length) {
      final int stepWhenStarted = _currentStep;

      // 🚨 Ensure TTS engine speaks in the correct OS dialect
      await _tts.setLanguage(activeDialect.ttsCode);
      await _tts.speak(scriptList[_currentStep]);

      // Pause for 3.5 seconds of psychological processing/breathing time
      await Future.delayed(const Duration(milliseconds: 3500));

      // Auto-advance ONLY if user hasn't manually tapped ahead and we aren't at the end
      if (mounted &&
          _currentStep == stepWhenStarted &&
          _currentStep < scriptList.length - 1) {
        _nextStep(isAutoAdvance: true);
      }
    }
  }

  Future<void> _nextStep({bool isAutoAdvance = false}) async {
    final activeDialect = ref.read(languageProvider);
    final scriptList = _localL10n[activeDialect.code] ?? _localL10n['en-IN']!;

    if (_isAnimating || _currentStep >= scriptList.length - 1) return;

    if (!isAutoAdvance) {
      await _tts.stop();
      // Minimal haptic on manual tap so we don't startle a sleepy user
      if (ref.read(sensoryProvider).hapticsEnabled) {
        HapticFeedback.lightImpact();
      }
    }

    setState(() => _isAnimating = true);
    await _fadeController.reverse();

    if (mounted) {
      setState(() => _currentStep++);
      await _fadeController.forward();
      setState(() => _isAnimating = false);

      _handleVoiceGuidance();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _fadeController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVoiceEnabled = ref.watch(sensoryProvider).voiceGuidanceEnabled;
    final activeDialect = ref.watch(languageProvider);
    final scriptList = _localL10n[activeDialect.code] ?? _localL10n['en-IN']!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Force status bar to be completely dark and unobtrusive
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _pureBlack,
      ),
      child: Scaffold(
        backgroundColor: _pureBlack, // Pure Black Background
        body: Stack(
          children: [
            // BACKGROUND: Hypnotic Breathing Orb
            Center(
              child: AnimatedBuilder(
                animation: _breathAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _breathAnimation.value,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _deepWarmGlow.withValues(alpha: 0.12),
                            blurRadius: 80,
                            spreadRadius: 40,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // FOREGROUND: Interactive Area & Text
            SafeArea(
              child: Column(
                children: [
                  // Minimal AppBar
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: _warmAmberText.withValues(alpha: 0.5),
                        ),
                        onPressed: () {
                          _tts.stop();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),

                  // Text Content Area
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _nextStep(isAutoAdvance: false),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(),

                            // Script Text (Dynamically bound to localization)
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Text(
                                scriptList[_currentStep],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  height: 1.5,
                                  color: _warmAmberText, // Blue-light free
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),

                            const Spacer(),

                            // Gentle Progress Indicator
                            if (_currentStep < scriptList.length - 1)
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 40.0),
                                  child: Text(
                                    isVoiceEnabled
                                        ? (activeDialect.code == 'en-IN' ? 'Auto-playing... Tap to skip' : 'Auto-playing...')
                                        : (activeDialect.code == 'en-IN' ? 'Tap anywhere to continue' : 'Tap to continue'),
                                    style: TextStyle(
                                      color: _warmAmberText.withValues(alpha: 0.3),
                                      fontSize: 14,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}