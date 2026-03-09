import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.type});

  final RequestEntryType type;

  @override
  Widget build(BuildContext context) {
    final RequestDetailModel detail = requestDetailFor(type);

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: Text(detail.title),
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PulseClockColors.appBackground,
              PulseClockColors.appBackgroundDeep,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PulseClockDimensions.horizontalPadding,
              PulseClockDimensions.topPadding,
              PulseClockDimensions.horizontalPadding,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusCardSection(model: detail.statusCard),
                const SizedBox(height: 16),
                SurfaceCard(child: RequestDetailBody(type: type)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RequestDetailBody extends StatelessWidget {
  const RequestDetailBody({super.key, required this.type});

  final RequestEntryType type;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case RequestEntryType.missedPunch:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DetailInfoRow(label: 'Issue Date', value: 'March 6, 2026'),
            const SizedBox(height: 12),
            const Text(
              'Submit a correction request with your actual clock-out time.',
              style: PulseClockTextStyles.cardSubtitle,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Correction request flow coming soon.'),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: PulseClockColors.actionBlue,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Submit Correction Request',
                style: PulseClockTextStyles.contextAction,
              ),
            ),
          ],
        );
      case RequestEntryType.correctionPending:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailInfoRow(label: 'Request Date', value: 'March 5, 2026'),
            SizedBox(height: 12),
            DetailInfoRow(label: 'Status', value: 'Pending Review'),
            SizedBox(height: 12),
            Text(
              'Your attendance correction is currently with your manager.',
              style: PulseClockTextStyles.cardSubtitle,
            ),
          ],
        );
      case RequestEntryType.leaveDetails:
        return const Column(
          children: [
            LeaveDetailRow(label: 'Leave Type', value: 'Annual Leave'),
            SizedBox(height: 12),
            LeaveDetailRow(label: 'Duration', value: 'Full Day'),
            SizedBox(height: 12),
            LeaveDetailRow(label: 'Balance Remaining', value: '12 days'),
          ],
        );
    }
  }
}
