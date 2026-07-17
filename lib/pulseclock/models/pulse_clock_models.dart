import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/styles.dart';

enum AttendanceStatus { offDuty, onDuty, leavePending, onLeave }

enum RequestEntryType { missedPunch, correctionPending, leaveDetails }

enum AttendanceRecordStatus {
  onDuty,
  completed,
  missedPunch,
  correctionPending,
  leavePending,
  onLeave,
  absent,
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
  leavePending,
  onLeave,
  absent,
}

enum CorrectionType { clockIn, clockOut, both }

enum CorrectionRequestStatus { pending }

enum LeaveType { annualLeave, sickLeave, other }

enum LeaveRequestStatus { pendingApproval, approved, rejected }

enum ClockActionMode { clockIn, clockOut }

enum WorkPulseNotificationType {
  clockInReminder,
  clockOutReminder,
  missedPunchReminder,
  leaveUpdate,
  generalInfo,
}

enum NotificationNavigationTarget {
  clockInConfirmation,
  clockOutConfirmation,
  correctionList,
  correctionDetails,
  leaveList,
  leaveDetails,
}

extension AttendanceRecordStatusLabels on AttendanceRecordStatus {
  String get label {
    switch (this) {
      case AttendanceRecordStatus.onDuty:
        return 'On Duty';
      case AttendanceRecordStatus.completed:
        return 'Completed';
      case AttendanceRecordStatus.missedPunch:
        return 'Missed Punch';
      case AttendanceRecordStatus.correctionPending:
        return 'Correction Pending';
      case AttendanceRecordStatus.leavePending:
        return 'Leave Pending';
      case AttendanceRecordStatus.onLeave:
        return 'On Leave';
      case AttendanceRecordStatus.absent:
        return 'Absent';
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
      case HistoryStatusFilter.leavePending:
        return 'Leave Pending';
      case HistoryStatusFilter.onLeave:
        return 'On Leave';
      case HistoryStatusFilter.absent:
        return 'Absent';
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
      case HistoryStatusFilter.leavePending:
        return AttendanceRecordStatus.leavePending;
      case HistoryStatusFilter.onLeave:
        return AttendanceRecordStatus.onLeave;
      case HistoryStatusFilter.absent:
        return AttendanceRecordStatus.absent;
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

extension LeaveTypeLabels on LeaveType {
  String get label {
    switch (this) {
      case LeaveType.annualLeave:
        return 'Annual Leave';
      case LeaveType.sickLeave:
        return 'Sick Leave';
      case LeaveType.other:
        return 'Other';
    }
  }
}

extension LeaveRequestStatusLabels on LeaveRequestStatus {
  String get label {
    switch (this) {
      case LeaveRequestStatus.pendingApproval:
        return 'Pending Approval';
      case LeaveRequestStatus.approved:
        return 'Approved';
      case LeaveRequestStatus.rejected:
        return 'Rejected';
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

extension WorkPulseNotificationTypeLabels on WorkPulseNotificationType {
  String get label {
    switch (this) {
      case WorkPulseNotificationType.clockInReminder:
        return 'Clock In Reminder';
      case WorkPulseNotificationType.clockOutReminder:
        return 'Clock Out Reminder';
      case WorkPulseNotificationType.missedPunchReminder:
        return 'Missed Punch Reminder';
      case WorkPulseNotificationType.leaveUpdate:
        return 'Leave Update';
      case WorkPulseNotificationType.generalInfo:
        return 'Info';
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

extension ClockLocationSnapshotLabels on ClockLocationSnapshot {
  String get geofenceLabel {
    return isInsideGeofence ? 'Inside Geofence' : 'Outside Geofence';
  }
}

class ReminderConfig {
  const ReminderConfig({
    required this.workdayStartHour,
    required this.clockOutReminderHour,
    required this.missedPunchBufferMinutes,
  });

  final int workdayStartHour;
  final int clockOutReminderHour;
  final int missedPunchBufferMinutes;
}

class WorkPulseNotification {
  const WorkPulseNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    this.actionLabel,
    this.navigationTarget,
    this.attendanceRecordId,
    this.correctionRequestId,
    this.leaveRequestId,
  });

  final String id;
  final WorkPulseNotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? actionLabel;
  final NotificationNavigationTarget? navigationTarget;
  final String? attendanceRecordId;
  final String? correctionRequestId;
  final String? leaveRequestId;

  WorkPulseNotification copyWith({
    String? id,
    WorkPulseNotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? actionLabel,
    NotificationNavigationTarget? navigationTarget,
    String? attendanceRecordId,
    String? correctionRequestId,
    String? leaveRequestId,
  }) {
    return WorkPulseNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      actionLabel: actionLabel ?? this.actionLabel,
      navigationTarget: navigationTarget ?? this.navigationTarget,
      attendanceRecordId: attendanceRecordId ?? this.attendanceRecordId,
      correctionRequestId: correctionRequestId ?? this.correctionRequestId,
      leaveRequestId: leaveRequestId ?? this.leaveRequestId,
    );
  }
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
    this.clockInLocation,
    this.clockOutLocation,
  });

  final String id;
  final DateTime date;
  final String clockInTime;
  final String clockOutTime;
  final String workHours;
  final AttendanceRecordStatus status;
  final String? note;
  final ClockLocationSnapshot? clockInLocation;
  final ClockLocationSnapshot? clockOutLocation;

  AttendanceRecord copyWith({
    String? id,
    DateTime? date,
    String? clockInTime,
    String? clockOutTime,
    String? workHours,
    AttendanceRecordStatus? status,
    String? note,
    ClockLocationSnapshot? clockInLocation,
    ClockLocationSnapshot? clockOutLocation,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      clockInTime: clockInTime ?? this.clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      workHours: workHours ?? this.workHours,
      status: status ?? this.status,
      note: note ?? this.note,
      clockInLocation: clockInLocation ?? this.clockInLocation,
      clockOutLocation: clockOutLocation ?? this.clockOutLocation,
    );
  }
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.submittedAt,
    this.reviewerNote,
  });

  final String id;
  final LeaveType type;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveRequestStatus status;
  final DateTime submittedAt;
  final String? reviewerNote;

  LeaveRequest copyWith({
    String? id,
    LeaveType? type,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    LeaveRequestStatus? status,
    DateTime? submittedAt,
    String? reviewerNote,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewerNote: reviewerNote ?? this.reviewerNote,
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
