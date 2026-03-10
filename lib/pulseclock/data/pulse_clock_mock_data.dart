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

List<AttendanceRecord> attendanceHistoryRecords({DateTime? now}) {
  final DateTime today = _dateOnly(now ?? DateTime.now());

  final List<AttendanceRecord> records = <AttendanceRecord>[
    AttendanceRecord(
      id: 'WRK-1001',
      date: today,
      clockInTime: '08:01 AM',
      clockOutTime: '05:10 PM',
      workHours: '9h 9m',
      status: AttendanceRecordStatus.completed,
    ),
    AttendanceRecord(
      id: 'WRK-1002',
      date: today.subtract(const Duration(days: 1)),
      clockInTime: '08:08 AM',
      clockOutTime: '--',
      workHours: '--',
      status: AttendanceRecordStatus.missedPunch,
      note: 'Clock Out was not captured.',
    ),
    AttendanceRecord(
      id: 'WRK-1003',
      date: today.subtract(const Duration(days: 2)),
      clockInTime: '08:15 AM',
      clockOutTime: '04:59 PM',
      workHours: '8h 44m',
      status: AttendanceRecordStatus.correctionPending,
      note: 'Correction requested for late Clock In.',
    ),
    AttendanceRecord(
      id: 'WRK-1004',
      date: today.subtract(const Duration(days: 3)),
      clockInTime: '--',
      clockOutTime: '--',
      workHours: '--',
      status: AttendanceRecordStatus.onLeave,
      note: 'Annual leave approved.',
    ),
    AttendanceRecord(
      id: 'WRK-1005',
      date: today.subtract(const Duration(days: 4)),
      clockInTime: '07:56 AM',
      clockOutTime: '05:03 PM',
      workHours: '9h 7m',
      status: AttendanceRecordStatus.completed,
    ),
    AttendanceRecord(
      id: 'WRK-1006',
      date: today.subtract(const Duration(days: 6)),
      clockInTime: '08:09 AM',
      clockOutTime: '05:02 PM',
      workHours: '8h 53m',
      status: AttendanceRecordStatus.completed,
    ),
    AttendanceRecord(
      id: 'WRK-1007',
      date: today.subtract(const Duration(days: 8)),
      clockInTime: '08:21 AM',
      clockOutTime: '--',
      workHours: '--',
      status: AttendanceRecordStatus.missedPunch,
      note: 'Shift ended but Clock Out was not done.',
    ),
    AttendanceRecord(
      id: 'WRK-1008',
      date: today.subtract(const Duration(days: 10)),
      clockInTime: '08:02 AM',
      clockOutTime: '04:57 PM',
      workHours: '8h 55m',
      status: AttendanceRecordStatus.completed,
    ),
    AttendanceRecord(
      id: 'WRK-1009',
      date: DateTime(today.year, today.month, 1).subtract(
        const Duration(days: 2),
      ),
      clockInTime: '--',
      clockOutTime: '--',
      workHours: '--',
      status: AttendanceRecordStatus.onLeave,
      note: 'Sick leave.',
    ),
    AttendanceRecord(
      id: 'WRK-1010',
      date: DateTime(today.year, today.month, 1).subtract(
        const Duration(days: 4),
      ),
      clockInTime: '08:05 AM',
      clockOutTime: '05:00 PM',
      workHours: '8h 55m',
      status: AttendanceRecordStatus.completed,
    ),
    AttendanceRecord(
      id: 'WRK-1011',
      date: DateTime(today.year, today.month, 1).subtract(
        const Duration(days: 6),
      ),
      clockInTime: '08:33 AM',
      clockOutTime: '05:04 PM',
      workHours: '8h 31m',
      status: AttendanceRecordStatus.correctionPending,
      note: 'Correction submitted for late Clock In.',
    ),
    AttendanceRecord(
      id: 'WRK-1012',
      date: DateTime(today.year, today.month, 1).subtract(
        const Duration(days: 8),
      ),
      clockInTime: '08:11 AM',
      clockOutTime: '--',
      workHours: '--',
      status: AttendanceRecordStatus.missedPunch,
      note: 'Missing Clock Out event.',
    ),
  ];

  records.sort((AttendanceRecord a, AttendanceRecord b) {
    return b.date.compareTo(a.date);
  });

  return records;
}

List<AttendanceRecord> filterAttendanceHistoryRecords({
  required List<AttendanceRecord> records,
  required HistoryDateRangeFilter dateRange,
  required HistoryStatusFilter statusFilter,
  DateTime? now,
}) {
  final DateTime today = _dateOnly(now ?? DateTime.now());
  final _DateWindow window = _windowForDateRange(today, dateRange);
  final AttendanceRecordStatus? selectedStatus = statusFilter.statusOrNull;

  return records.where((AttendanceRecord record) {
    final DateTime recordDate = _dateOnly(record.date);
    final bool inWindow =
        !recordDate.isBefore(window.start) && recordDate.isBefore(window.end);
    final bool statusMatches =
        selectedStatus == null || record.status == selectedStatus;
    return inWindow && statusMatches;
  }).toList(growable: false);
}

_DateWindow _windowForDateRange(DateTime today, HistoryDateRangeFilter filter) {
  switch (filter) {
    case HistoryDateRangeFilter.today:
      return _DateWindow(
        start: today,
        end: today.add(const Duration(days: 1)),
      );
    case HistoryDateRangeFilter.yesterday:
      final DateTime start = today.subtract(const Duration(days: 1));
      return _DateWindow(start: start, end: start.add(const Duration(days: 1)));
    case HistoryDateRangeFilter.thisWeek:
      final DateTime start = today.subtract(Duration(days: today.weekday - 1));
      return _DateWindow(start: start, end: start.add(const Duration(days: 7)));
    case HistoryDateRangeFilter.lastWeek:
      final DateTime end = today.subtract(Duration(days: today.weekday - 1));
      return _DateWindow(start: end.subtract(const Duration(days: 7)), end: end);
    case HistoryDateRangeFilter.thisMonth:
      final DateTime start = DateTime(today.year, today.month, 1);
      final DateTime end = DateTime(today.year, today.month + 1, 1);
      return _DateWindow(start: start, end: end);
    case HistoryDateRangeFilter.lastMonth:
      final DateTime start = DateTime(today.year, today.month - 1, 1);
      final DateTime end = DateTime(today.year, today.month, 1);
      return _DateWindow(start: start, end: end);
  }
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

class _DateWindow {
  const _DateWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class WorkPulseMockStore extends ChangeNotifier {
  WorkPulseMockStore._internal() {
    _attendanceRecords = attendanceHistoryRecords();
    _seedInitialPendingRequest();
  }

  static final WorkPulseMockStore instance = WorkPulseMockStore._internal();

  late final List<AttendanceRecord> _attendanceRecords;
  final List<CorrectionRequest> _correctionRequests = <CorrectionRequest>[];
  int _correctionSequence = 1;

  List<AttendanceRecord> get attendanceRecords {
    return List<AttendanceRecord>.unmodifiable(_attendanceRecords);
  }

  List<CorrectionRequest> get correctionRequests {
    return List<CorrectionRequest>.unmodifiable(_correctionRequests);
  }

  List<CorrectionRequest> get pendingCorrectionRequests {
    return List<CorrectionRequest>.unmodifiable(
      _correctionRequests.where(
        (CorrectionRequest request) =>
            request.status == CorrectionRequestStatus.pending,
      ),
    );
  }

  List<AttendanceRecord> get missedPunchRecords {
    final List<AttendanceRecord> records = _attendanceRecords
        .where(
          (AttendanceRecord record) =>
              record.status == AttendanceRecordStatus.missedPunch,
        )
        .toList();
    records.sort((AttendanceRecord a, AttendanceRecord b) {
      return a.date.compareTo(b.date);
    });
    return List<AttendanceRecord>.unmodifiable(
      records,
    );
  }

  AttendanceRecord? get latestMissedPunchRecord {
    for (final AttendanceRecord record in _attendanceRecords) {
      if (record.status == AttendanceRecordStatus.missedPunch) {
        return record;
      }
    }
    return null;
  }

  CorrectionRequest? get latestPendingCorrectionRequest {
    for (final CorrectionRequest request in _correctionRequests) {
      if (request.status == CorrectionRequestStatus.pending) {
        return request;
      }
    }
    return null;
  }

  AttendanceRecord? attendanceRecordById(String id) {
    for (final AttendanceRecord record in _attendanceRecords) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  CorrectionRequest? correctionRequestById(String id) {
    for (final CorrectionRequest request in _correctionRequests) {
      if (request.id == id) {
        return request;
      }
    }
    return null;
  }

  CorrectionRequest submitCorrectionRequest({
    required String attendanceRecordId,
    required String issueSummary,
    required CorrectionType correctionType,
    required String reason,
    String? correctedClockInTime,
    String? correctedClockOutTime,
    String? existingRequestId,
  }) {
    final AttendanceRecord? existingRecord = attendanceRecordById(
      attendanceRecordId,
    );
    if (existingRecord == null) {
      throw ArgumentError('Attendance record not found for ID: $attendanceRecordId');
    }

    if (existingRequestId != null) {
      final int existingRequestIndex = _correctionRequests.indexWhere(
        (CorrectionRequest request) => request.id == existingRequestId,
      );
      if (existingRequestIndex >= 0) {
        final CorrectionRequest currentRequest =
            _correctionRequests[existingRequestIndex];
        if (currentRequest.attendanceRecordId != attendanceRecordId) {
          throw ArgumentError(
            'Correction request does not belong to attendance record: $attendanceRecordId',
          );
        }

        final CorrectionRequest updatedRequest = CorrectionRequest(
          id: currentRequest.id,
          attendanceRecordId: attendanceRecordId,
          affectedDate: existingRecord.date,
          issueSummary: issueSummary,
          correctionType: correctionType,
          reason: reason,
          status: CorrectionRequestStatus.pending,
          submittedAt: DateTime.now(),
          correctedClockInTime: correctedClockInTime,
          correctedClockOutTime: correctedClockOutTime,
        );

        _correctionRequests.removeAt(existingRequestIndex);
        _correctionRequests.insert(0, updatedRequest);
        _markAttendanceAsCorrectionPending(
          attendanceRecordId: attendanceRecordId,
          issueSummary: issueSummary,
        );
        notifyListeners();
        return updatedRequest;
      }
    }

    final String requestId = 'CR-${_correctionSequence.toString().padLeft(4, '0')}';
    _correctionSequence += 1;

    final CorrectionRequest request = CorrectionRequest(
      id: requestId,
      attendanceRecordId: attendanceRecordId,
      affectedDate: existingRecord.date,
      issueSummary: issueSummary,
      correctionType: correctionType,
      reason: reason,
      status: CorrectionRequestStatus.pending,
      submittedAt: DateTime.now(),
      correctedClockInTime: correctedClockInTime,
      correctedClockOutTime: correctedClockOutTime,
    );

    _correctionRequests.insert(0, request);
    _markAttendanceAsCorrectionPending(
      attendanceRecordId: attendanceRecordId,
      issueSummary: issueSummary,
    );
    notifyListeners();

    return request;
  }

  void _markAttendanceAsCorrectionPending({
    required String attendanceRecordId,
    required String issueSummary,
  }) {
    final int index = _attendanceRecords.indexWhere(
      (AttendanceRecord record) => record.id == attendanceRecordId,
    );
    if (index < 0) {
      return;
    }

    _attendanceRecords[index] = _attendanceRecords[index].copyWith(
      status: AttendanceRecordStatus.correctionPending,
      note: issueSummary,
    );
  }

  void _seedInitialPendingRequest() {
    final AttendanceRecord pendingRecord = _attendanceRecords.firstWhere(
      (AttendanceRecord record) =>
          record.status == AttendanceRecordStatus.correctionPending,
      orElse: () => _attendanceRecords.first,
    );

    if (pendingRecord.status != AttendanceRecordStatus.correctionPending) {
      return;
    }

    _correctionRequests.add(
      CorrectionRequest(
        id: 'CR-0001',
        attendanceRecordId: pendingRecord.id,
        affectedDate: pendingRecord.date,
        issueSummary: pendingRecord.note ?? 'Correction submitted.',
        correctionType: CorrectionType.clockIn,
        reason: 'Submitted for manager review.',
        status: CorrectionRequestStatus.pending,
        submittedAt: DateTime.now().subtract(const Duration(hours: 6)),
        correctedClockInTime: '08:00 AM',
      ),
    );
    _correctionSequence = 2;
  }
}
