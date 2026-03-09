import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';

StatusCardModel statusCardFor(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.offDuty:
      return const StatusCardModel(
        title: 'Off Duty',
        subtitle: 'Ready to start your workday',
        icon: Icons.access_time_outlined,
        backgroundColor: PulseClockColors.statusOffDutyBg,
        accentColor: PulseClockColors.statusOffDutyAccent,
      );
    case AttendanceStatus.onDuty:
      return const StatusCardModel(
        title: 'On Duty',
        subtitle: 'You clocked in at 09:15 AM',
        icon: Icons.check_circle_outline,
        backgroundColor: PulseClockColors.statusOnDutyBg,
        accentColor: PulseClockColors.statusOnDutyAccent,
      );
  }
}

PrimaryActionModel primaryActionFor(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.offDuty:
      return const PrimaryActionModel(
        label: 'Clock In',
        icon: Icons.access_time_outlined,
        backgroundColor: PulseClockColors.actionBlue,
        foregroundColor: PulseClockColors.surface,
      );
    case AttendanceStatus.onDuty:
      return const PrimaryActionModel(
        label: 'Clock Out',
        icon: Icons.access_time_outlined,
        backgroundColor: PulseClockColors.actionRed,
        foregroundColor: PulseClockColors.surface,
      );
  }
}

SummaryModel summaryFor(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.offDuty:
      return const SummaryModel(
        punchIn: '--',
        punchOut: '--',
        workHours: '0h 0m',
      );
    case AttendanceStatus.onDuty:
      return const SummaryModel(
        punchIn: '19:15',
        punchOut: '--',
        workHours: '3h 42m',
      );
  }
}

RequestEntryModel requestEntryFor(RequestEntryType type) {
  switch (type) {
    case RequestEntryType.missedPunch:
      return const RequestEntryModel(
        title: 'Missed Punch',
        subtitle: 'You missed clocking out yesterday',
        icon: Icons.cancel_outlined,
        backgroundColor: PulseClockColors.statusMissedBg,
        accentColor: PulseClockColors.statusMissedAccent,
      );
    case RequestEntryType.correctionPending:
      return const RequestEntryModel(
        title: 'Correction Pending',
        subtitle: 'Your attendance correction is under review',
        icon: Icons.pending_actions_outlined,
        backgroundColor: PulseClockColors.statusPendingBg,
        accentColor: PulseClockColors.statusPendingAccent,
      );
    case RequestEntryType.leaveDetails:
      return const RequestEntryModel(
        title: 'Leave Details',
        subtitle: 'Annual Leave (Full Day)',
        icon: Icons.beach_access_outlined,
        backgroundColor: PulseClockColors.statusLeaveBg,
        accentColor: PulseClockColors.statusLeaveAccent,
      );
  }
}

RequestDetailModel requestDetailFor(RequestEntryType type) {
  switch (type) {
    case RequestEntryType.missedPunch:
      return const RequestDetailModel(
        title: 'Missed Punch',
        statusCard: StatusCardModel(
          title: 'Action Required',
          subtitle: 'Submit a correction request for March 6, 2026',
          icon: Icons.assignment_late_outlined,
          backgroundColor: PulseClockColors.statusMissedBg,
          accentColor: PulseClockColors.statusMissedAccent,
        ),
      );
    case RequestEntryType.correctionPending:
      return const RequestDetailModel(
        title: 'Correction Pending',
        statusCard: StatusCardModel(
          title: 'Pending Review',
          subtitle: 'Correction for March 5, 2026',
          icon: Icons.pending_actions_outlined,
          backgroundColor: PulseClockColors.statusPendingBg,
          accentColor: PulseClockColors.statusPendingAccent,
        ),
      );
    case RequestEntryType.leaveDetails:
      return const RequestDetailModel(
        title: 'Leave Details',
        statusCard: StatusCardModel(
          title: 'On Leave',
          subtitle: 'Annual Leave (Full Day)',
          icon: Icons.beach_access_outlined,
          backgroundColor: PulseClockColors.statusLeaveBg,
          accentColor: PulseClockColors.statusLeaveAccent,
        ),
      );
  }
}
