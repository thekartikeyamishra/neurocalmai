import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  final String code;
  final String displayName;
  final String ttsCode; // The code FlutterTts needs to pronounce it

  const AppLanguage(this.code, this.displayName, this.ttsCode);
}

class LanguageNotifier extends Notifier<AppLanguage> {
  SharedPreferences? _prefs;

  // Pre-configured major Indian languages and dialects
  static const List<AppLanguage> supportedLanguages = [
    AppLanguage('en-IN', 'English', 'en-IN'),
    AppLanguage('hi-IN', 'हिंदी (Hindi)', 'hi-IN'),
    AppLanguage('mr-IN', 'मराठी (Marathi)', 'mr-IN'),
    AppLanguage('bn-IN', 'বাংলা (Bengali)', 'bn-IN'),
    AppLanguage('ta-IN', 'தமிழ் (Tamil)', 'ta-IN'),
    AppLanguage('te-IN', 'తెలుగు (Telugu)', 'te-IN'),
  ];

  @override
  AppLanguage build() {
    _loadLanguage();
    return supportedLanguages.first; // Default to English
  }

  Future<void> _loadLanguage() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedCode = _prefs?.getString('app_language_code') ?? 'en-IN';
      
      state = supportedLanguages.firstWhere(
        (lang) => lang.code == savedCode,
        orElse: () => supportedLanguages.first,
      );
    } catch (e) {
      debugPrint('[LanguageProvider Error]: Failed to load language - $e');
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString('app_language_code', language.code);
    } catch (e) {
      debugPrint('[LanguageProvider Error]: Failed to save language - $e');
    }
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(() {
  return LanguageNotifier();
});