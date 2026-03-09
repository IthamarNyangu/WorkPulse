import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class AttendanceHistoryDetailScreen extends StatelessWidget {
  const AttendanceHistoryDetailScreen({super.key, required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final bool showCorrectionAction =
        record.status == AttendanceRecordStatus.missedPunch;

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Attendance Details'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              PulseClockDimensions.horizontalPadding,
              PulseClockDimensions.topPadding,
              PulseClockDimensions.horizontalPadding,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateLabel(record.date),
                              style: PulseClockTextStyles.cardTitle.copyWith(
                                fontSize: 22,
                              ),
                            ),
                          ),
                          HistoryStatusBadge(status: record.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: PulseClockColors.cardBorder),
                      const SizedBox(height: 12),
                      DetailInfoRow(label: 'Record ID', value: record.id),
                      const SizedBox(height: 10),
                      DetailInfoRow(
                        label: 'Day',
                        value: weekdayName(record.date),
                      ),
                      const SizedBox(height: 10),
                      DetailInfoRow(label: 'Clock In', value: record.clockInTime),
                      const SizedBox(height: 10),
                      DetailInfoRow(
                        label: 'Clock Out',
                        value: record.clockOutTime,
                      ),
                      const SizedBox(height: 10),
                      DetailInfoRow(
                        label: 'Work Hours',
                        value: record.workHours,
                      ),
                      if (record.note != null) ...<Widget>[
                        const SizedBox(height: 12),
                        const Divider(color: PulseClockColors.cardBorder),
                        const SizedBox(height: 12),
                        Text(
                          'Notes',
                          style: PulseClockTextStyles.cardSubtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.note!,
                          style: PulseClockTextStyles.cardSubtitle,
                        ),
                      ],
                    ],
                  ),
                ),
                if (showCorrectionAction) ...<Widget>[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Correction request flow coming soon.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Request Correction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PulseClockColors.actionBlue,
                        foregroundColor: PulseClockColors.surface,
                        textStyle: PulseClockTextStyles.contextAction.copyWith(
                          color: PulseClockColors.surface,
                          fontSize: 17,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PulseClockDimensions.cardRadius,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
