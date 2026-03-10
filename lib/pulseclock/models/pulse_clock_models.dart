import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/styles.dart';

enum AttendanceStatus { offDuty, onDuty }

enum RequestEntryType { missedPunch, correctionPending, leaveDetails }

enum AttendanceRecordStatus {
  completed,
  missedPunch,
  correctionPending,
  onLeave,
}

enum HistoryDateRangeFilter {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
}

enum HistoryStatusFilter {
  all,
  completed,
  missedPunch,
  correctionPending,
  onLeave,
}

enum CorrectionType { clockIn, clockOut, both }

enum CorrectionRequestStatus { pending }

enum ClockActionMode { clockIn, clockOut }

extension AttendanceRecordStatusLabels on AttendanceRecordStatus {
  String get label {
    switch (this) {
      case AttendanceRecordStatus.completed:
        return 'Completed';
      case AttendanceRecordStatus.missedPunch:
        return 'Missed Punch';
      case AttendanceRecordStatus.correctionPending:
        return 'Correction Pending';
      case AttendanceRecordStatus.onLeave:
        return 'On Leave';
    }
  }
}

extension HistoryDateRangeFilterLabels on HistoryDateRangeFilter {
  String get label {
    switch (this) {
      case HistoryDateRangeFilter.today:
        return 'Today';
      case HistoryDateRangeFilter.yesterday:
        return 'Yesterday';
      case HistoryDateRangeFilter.thisWeek:
        return 'This Week';
      case HistoryDateRangeFilter.lastWeek:
        return 'Last Week';
      case HistoryDateRangeFilter.thisMonth:
        return 'This Month';
      case HistoryDateRangeFilter.lastMonth:
        return 'Last Month';
    }
  }
}

extension HistoryStatusFilterLabels on HistoryStatusFilter {
  String get label {
    switch (this) {
      case HistoryStatusFilter.all:
        return 'All';
      case HistoryStatusFilter.completed:
        return 'Completed';
      case HistoryStatusFilter.missedPunch:
        return 'Missed Punch';
      case HistoryStatusFilter.correctionPending:
        return 'Correction Pending';
      case HistoryStatusFilter.onLeave:
        return 'On Leave';
    }
  }

  AttendanceRecordStatus? get statusOrNull {
    switch (this) {
      case HistoryStatusFilter.all:
        return null;
      case HistoryStatusFilter.completed:
        return AttendanceRecordStatus.completed;
      case HistoryStatusFilter.missedPunch:
        return AttendanceRecordStatus.missedPunch;
      case HistoryStatusFilter.correctionPending:
        return AttendanceRecordStatus.correctionPending;
      case HistoryStatusFilter.onLeave:
        return AttendanceRecordStatus.onLeave;
    }
  }
}

extension CorrectionTypeLabels on CorrectionType {
  String get label {
    switch (this) {
      case CorrectionType.clockIn:
        return 'Clock In';
      case CorrectionType.clockOut:
        return 'Clock Out';
      case CorrectionType.both:
        return 'Both';
    }
  }
}

extension CorrectionRequestStatusLabels on CorrectionRequestStatus {
  String get label {
    switch (this) {
      case CorrectionRequestStatus.pending:
        return 'Pending';
    }
  }
}

extension ClockActionModeLabels on ClockActionMode {
  String get title {
    switch (this) {
      case ClockActionMode.clockIn:
        return 'Confirm Clock In';
      case ClockActionMode.clockOut:
        return 'Confirm Clock Out';
    }
  }

  String get confirmLabel {
    switch (this) {
      case ClockActionMode.clockIn:
        return 'Confirm Clock In';
      case ClockActionMode.clockOut:
        return 'Confirm Clock Out';
    }
  }

  IconData get icon {
    switch (this) {
      case ClockActionMode.clockIn:
        return Icons.login_rounded;
      case ClockActionMode.clockOut:
        return Icons.logout_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ClockActionMode.clockIn:
        return PulseClockColors.actionBlue;
      case ClockActionMode.clockOut:
        return PulseClockColors.actionRed;
    }
  }
}

class ClockConfirmationResult {
  const ClockConfirmationResult({
    required this.mode,
    required this.timestamp,
    this.comment,
  });

  final ClockActionMode mode;
  final DateTime timestamp;
  final String? comment;
}

class ClockLocationSnapshot {
  const ClockLocationSnapshot({
    required this.coordinates,
    required this.accuracyMeters,
    required this.isInsideGeofence,
  });

  final String coordinates;
  final double accuracyMeters;
  final bool isInsideGeofence;
}

class StatusCardModel {
  const StatusCardModel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color accentColor;
}

class PrimaryActionModel {
  const PrimaryActionModel({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}

class SummaryModel {
  const SummaryModel({
    required this.punchIn,
    required this.punchOut,
    required this.workHours,
  });

  final String punchIn;
  final String punchOut;
  final String workHours;
}

class RequestEntryModel {
  const RequestEntryModel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color accentColor;
}

class RequestDetailModel {
  const RequestDetailModel({required this.title, required this.statusCard});

  final String title;
  final StatusCardModel statusCard;
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.clockInTime,
    required this.clockOutTime,
    required this.workHours,
    required this.status,
    this.note,
  });

  final String id;
  final DateTime date;
  final String clockInTime;
  final String clockOutTime;
  final String workHours;
  final AttendanceRecordStatus status;
  final String? note;

  AttendanceRecord copyWith({
    String? id,
    DateTime? date,
    String? clockInTime,
    String? clockOutTime,
    String? workHours,
    AttendanceRecordStatus? status,
    String? note,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      clockInTime: clockInTime ?? this.clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      workHours: workHours ?? this.workHours,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}

class CorrectionRequest {
  const CorrectionRequest({
    required this.id,
    required this.attendanceRecordId,
    required this.affectedDate,
    required this.issueSummary,
    required this.correctionType,
    required this.reason,
    required this.status,
    required this.submittedAt,
    this.correctedClockInTime,
    this.correctedClockOutTime,
  });

  final String id;
  final String attendanceRecordId;
  final DateTime affectedDate;
  final String issueSummary;
  final CorrectionType correctionType;
  final String reason;
  final CorrectionRequestStatus status;
  final DateTime submittedAt;
  final String? correctedClockInTime;
  final String? correctedClockOutTime;
}
