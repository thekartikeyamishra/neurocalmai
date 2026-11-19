/// On-device crisis phrase check (mirrors functions/src/ai.ts). Runs before
/// any network call so the safety sheet appears even when offline.
class CrisisDetector {
  CrisisDetector._();

  static final List<RegExp> _patterns = [
    RegExp(r'\b(kill|hurt|harm)\s+(myself|my\s*self)\b', caseSensitive: false),
    RegExp(r'\bsuicid(e|al)\b', caseSensitive: false),
    RegExp(r'\bend\s+(my\s+(own\s+)?life|it\s+all)\b', caseSensitive: false),
    RegExp(r'\bwant\s+to\s+die\b', caseSensitive: false),
    RegExp(r"\b(don'?t|do\s+not)\s+want\s+to\s+(live|be\s+alive|exist)\b", caseSensitive: false),
    RegExp(r'\bno\s+reason\s+to\s+live\b', caseSensitive: false),
    RegExp(r'\bself[\s-]?harm\b', caseSensitive: false),
    RegExp(r'\bcut(ting)?\s+myself\b', caseSensitive: false),
    RegExp(r'\b(khudkushi|khud\s*kushi|aatmhatya|atmahatya)\b', caseSensitive: false),
    RegExp(r'\bmar(na|ne)\s+(chahta|chahti|chahte)\b', caseSensitive: false),
    RegExp(r'\bjaan\s+de\s+(dunga|dungi|du)\b', caseSensitive: false),
    RegExp(r'आत्महत्या|ख़ुदकुशी|खुदकुशी|मरना\s*चाहत|जान\s*दे\s*द'),
  ];

  static bool isCrisis(String text) {
    final t = text.length > 4000 ? text.substring(0, 4000) : text;
    return _patterns.any((p) => p.hasMatch(t));
  }
}
