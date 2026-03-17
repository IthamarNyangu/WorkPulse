// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:pulseclock/main.dart';

void main() {
  testWidgets('PulseClock home renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PulseClockApp());

    expect(find.text('PulseClock'), findsOneWidget);
    expect(find.text('Welcome back, Ithamar'), findsOneWidget);
    expect(find.text("Today's Summary"), findsOneWidget);
    expect(find.text('Mock Status'), findsOneWidget);
  });
}
