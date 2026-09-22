import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulseclock/features/attendance/home/pulse_clock_home_screen.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

void main() {
  for (final Size size in <Size>[const Size(320, 568), const Size(430, 932)]) {
    testWidgets('home attendance content fits ${size.width}x${size.height}', (
      WidgetTester tester,
    ) async {
      bool clockOutPressed = false;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              color: const Color(0xFF5A1622),
              child: SafeArea(
                child: HomeTabContent(
                  now: DateTime(2026, 9, 22, 9, 46),
                  status: AttendanceStatus.onDuty,
                  employeeName: 'Ithamar',
                  statusCard: const StatusCardModel(
                    title: 'On Duty',
                    subtitle: 'You clocked in at 09:46',
                    icon: Icons.check_circle_outline,
                    backgroundColor: Color(0xFFECF1F8),
                    accentColor: Color(0xFF0F8A43),
                  ),
                  summary: const SummaryModel(
                    punchIn: '09:46',
                    punchOut: '--',
                    workHours: '2h 14m',
                  ),
                  onPrimaryActionPressed: () => clockOutPressed = true,
                  onNotificationsPressed: () {},
                  unreadNotifications: 2,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WorkPulse'), findsOneWidget);
      expect(find.text('09:46'), findsNWidgets(2));
      expect(find.text('On Duty'), findsOneWidget);
      expect(find.text("Today's Summary"), findsOneWidget);
      expect(find.text('2h 14m'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final Finder clockOutButton = find.widgetWithText(
        ElevatedButton,
        'Clock Out',
      );
      await tester.ensureVisible(clockOutButton);
      await tester.tap(clockOutButton);
      expect(clockOutPressed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bottom navigation keeps the existing destinations', (
    WidgetTester tester,
  ) async {
    int selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: PulseBottomNavigation(
            currentIndex: selectedIndex,
            onTap: (int index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('History'));
    expect(selectedIndex, 1);
  });
}
