import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulseclock/features/attendance/clock/clock_confirmation_screen.dart';
import 'package:pulseclock/features/attendance/location/workpulse_location_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';

void main() {
  Future<void> pumpConfirmationContent(
    WidgetTester tester, {
    required Size size,
    required WorkPulseLocationResult result,
    required VoidCallback onRetry,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ConfirmationDateTimeHeader(now: DateTime(2026, 9, 22, 9, 46)),
                const SizedBox(height: 18),
                ClockMapPlaceholderCard(
                  result: result,
                  isLoading: false,
                  onRetry: () async => onRetry(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  for (final Size size in <Size>[const Size(320, 568), const Size(430, 932)]) {
    testWidgets('confirmation content fits ${size.width}x${size.height}', (
      WidgetTester tester,
    ) async {
      bool retried = false;
      await pumpConfirmationContent(
        tester,
        size: size,
        result: const WorkPulseLocationResult(
          snapshot: ClockLocationSnapshot(
            coordinates: '-15.3875, 28.3228',
            accuracyMeters: 12,
            status: ClockLocationStatus.insideOffice,
            verifiedOfficeName: 'RTCZ Lusaka HQ',
          ),
          message: null,
          activeOfficeCount: 1,
        ),
        onRetry: () => retried = true,
      );

      expect(find.text('09:46'), findsOneWidget);
      expect(find.text('Location Verification'), findsOneWidget);
      expect(find.text('Within Geofence of RTCZ Lusaka HQ.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });
  }
}
