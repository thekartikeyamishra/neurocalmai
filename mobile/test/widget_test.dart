import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// FIXED: Using a relative import guarantees the compiler finds your main file 
// regardless of what the package name is set to in pubspec.yaml.
import '../lib/main.dart'; 

void main() {
  testWidgets('NeuroCalmApp Welcome Screen smoke test', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    // CRITICAL: We must wrap NeuroCalmApp in ProviderScope because our app uses Riverpod.
    await tester.pumpWidget(const ProviderScope(child: NeuroCalmApp()));

    // Let the entry animations (fade/slide) settle
    await tester.pumpAndSettle();

    // 2. Verify that our WelcomeScreen renders correctly by looking for the actual text we wrote.
    expect(find.text('Find your center.'), findsOneWidget);
    expect(find.text('Begin Session'), findsOneWidget);

    // 3. Verify that the old default counter app ghost is gone.
    expect(find.text('0'), findsNothing);
    // FIXED: The correct method is 'byIcon', not 'icon'.
    expect(find.byIcon(Icons.add), findsNothing);
  });
}