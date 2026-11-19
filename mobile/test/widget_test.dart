import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Neurocalm/core/safety/crisis_detector.dart';
import 'package:Neurocalm/features/onboarding/presentation/first_win_screen.dart';

void main() {
  group('CrisisDetector', () {
    test('flags explicit risk phrases (EN + Hinglish + Hindi)', () {
      for (final t in [
        'I want to kill myself',
        'thinking about suicide',
        'I just want to end my life',
        "I don't want to live anymore",
        'mujhe marna chahta hu',
        'मैं आत्महत्या के बारे में सोच रहा हूँ',
      ]) {
        expect(CrisisDetector.isCrisis(t), isTrue, reason: t);
      }
    });

    test('does not flag everyday stress language', () {
      for (final t in [
        "I'm going to fail my exam",
        'this deadline is killing me',
        'I want to end this meeting early',
        'my life is busy',
      ]) {
        expect(CrisisDetector.isCrisis(t), isFalse, reason: t);
      }
    });
  });

  testWidgets('First-win screen: CTA enabled only after picking a worry', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FirstWinScreen()));
    expect(find.text("What's weighing on you right now?"), findsOneWidget);

    final cta = find.widgetWithText(ElevatedButton, 'Untangle this thought');
    expect(tester.widget<ElevatedButton>(cta).onPressed, isNull);

    await tester.tap(find.text('Overthinking'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(cta).onPressed, isNotNull);
  });
}
