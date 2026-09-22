import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulseclock/features/notifications/notification_preferences_screen.dart';

void main() {
  for (final Size size in <Size>[const Size(320, 568), const Size(430, 932)]) {
    testWidgets('notification setting rows fit ${size.width}x${size.height}', (
      WidgetTester tester,
    ) async {
      final List<String> changed = <String>[];
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  NotificationPreferenceRow(
                    icon: Icons.schedule_outlined,
                    title: 'Basic Attendance Reminders',
                    subtitle:
                        'Clock in, clock out and missed attendance reminders.',
                    value: true,
                    enabled: true,
                    onChanged: (_) => changed.add('basic'),
                  ),
                  NotificationPreferenceRow(
                    icon: Icons.location_on_outlined,
                    title: 'Smart Location Reminders',
                    subtitle: 'Reminders for your approved work locations.',
                    value: true,
                    enabled: true,
                    onChanged: (_) => changed.add('location'),
                  ),
                  NotificationPreferenceRow(
                    icon: Icons.fact_check_outlined,
                    title: 'Request Updates',
                    subtitle: 'Leave and attendance correction updates.',
                    value: true,
                    enabled: true,
                    onChanged: (_) => changed.add('requests'),
                  ),
                  NotificationPreferenceRow(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notifications',
                    subtitle: 'Allow WorkPulse notifications on this device.',
                    value: true,
                    enabled: true,
                    onChanged: (_) => changed.add('push'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Basic Attendance Reminders'), findsOneWidget);
      expect(find.text('Smart Location Reminders'), findsOneWidget);
      expect(find.text('Request Updates'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final String title in <String>[
        'Basic Attendance Reminders',
        'Smart Location Reminders',
        'Request Updates',
        'Push Notifications',
      ]) {
        final Finder row = find.ancestor(
          of: find.text(title),
          matching: find.byType(ListTile),
        );
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pump();
      }

      expect(changed, <String>['basic', 'location', 'requests', 'push']);
      expect(tester.takeException(), isNull);
    });
  }
}
