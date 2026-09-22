import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulseclock/features/auth/presentation/welcome_screen.dart';

void main() {
  testWidgets('welcome screen presents WorkPulse and opens sign in', (
    WidgetTester tester,
  ) async {
    bool signInRequested = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          onSignIn: () => signInRequested = true,
        ),
      ),
    );

    expect(find.text('WorkPulse'), findsOneWidget);
    expect(find.text('Work made simpler'), findsOneWidget);
    expect(find.textContaining('smart reminders'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    expect(signInRequested, isTrue);
  });
}
