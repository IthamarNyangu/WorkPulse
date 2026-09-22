import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/auth/presentation/login_screen.dart';
import 'package:pulseclock/features/auth/presentation/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SupabaseBootstrap.initialize();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  for (final Size size in <Size>[const Size(320, 568), const Size(430, 932)]) {
    testWidgets('welcome screen fits ${size.width}x${size.height}', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(onSignIn: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('WorkPulse'), findsOneWidget);
      expect(find.text('Your workday, in sync.'), findsOneWidget);
      expect(find.textContaining('manage requests'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('login screen fits ${size.width}x${size.height}', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: LoginScreen(onBack: () {})));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        find.text('Sign in with your organisation account.'),
        findsOneWidget,
      );
      expect(find.text('Need access? Contact your HR team.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('login form remains usable with the keyboard open', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(onBack: () {})));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextFormField).last);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Welcome back'), findsOneWidget);
    final Finder signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
    expect(signInButton, findsOneWidget);
    expect(tester.getBottomRight(signInButton).dy, lessThanOrEqualTo(524));
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();

    expect(find.text('WorkPulse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
