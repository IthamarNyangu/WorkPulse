import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApprovalService {
  ApprovalService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client,
      _authService = AuthService(client: client ?? SupabaseBootstrap.client);

  static const String profilesTableName = 'profiles';
  static const String leaveTableName = 'leave_requests';
  static const String correctionTableName = 'correction_requests';
  static const String attendanceTableName = 'attendance_records';
  static const Set<String> reviewerRoles = <String>{
    'supervisor',
    'hr',
    'admin',
  };

  final SupabaseClient _client;
  final AuthService _authService;

  Future<bool> canReviewRequests() async {
    final WorkPulseUserProfile? profile = await _authService
        .fetchCurrentProfile();
    return profile != null && profile.hasAnyRole(reviewerRoles);
  }

  Future<ApprovalCounts> fetchApprovalCounts() async {
    final WorkPulseUserProfile reviewer = await _requireReviewerProfile();

    final List<dynamic> leaveRows = await _client
        .from(leaveTableName)
        .select('id')
        .eq('status', 'pending')
        .neq('user_id', reviewer.id);
    final List<dynamic> correctionRows = await _client
        .from(correctionTableName)
        .select('id')
        .eq('status', 'pending')
        .neq('user_id', reviewer.id);

    return ApprovalCounts(
      pendingLeaveCount: leaveRows.length,
      pendingCorrectionCount: correctionRows.length,
    );
  }

  Future<List<LeaveApprovalItem>> fetchPendingLeaveApprovals() async {
    final WorkPulseUserProfile reviewer = await _requireReviewerProfile();

    final List<dynamic> rows = await _client
        .from(leaveTableName)
        .select()
        .eq('status', 'pending')
        .neq('user_id', reviewer.id)
        .order('created_at', ascending: true);

    final List<Map<String, dynamic>> requests = rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final Map<String, ApprovalEmployeeProfile> profiles =
        await _profilesForRequests(requests);

    return requests
        .map(
          (Map<String, dynamic> row) =>
              _leaveApprovalFromMap(row, profiles[row['user_id'] as String]),
        )
        .toList(growable: false);
  }

  Future<List<LeaveApprovalItem>> fetchReviewedLeaveApprovals() async {
    final WorkPulseUserProfile reviewer = await _requireReviewerProfile();

    final List<dynamic> rows = await _client
        .from(leaveTableName)
        .select()
        .neq('status', 'pending')
        .neq('user_id', reviewer.id)
        .order('updated_at', ascending: false);

    final List<Map<String, dynamic>> requests = rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final Map<String, ApprovalEmployeeProfile> profiles =
        await _profilesForRequests(requests);

    return requests
        .map(
          (Map<String, dynamic> row) =>
              _leaveApprovalFromMap(row, profiles[row['user_id'] as String]),
        )
        .toList(growable: false);
  }

  Future<List<CorrectionApprovalItem>> fetchPendingCorrectionApprovals() async {
    final WorkPulseUserProfile reviewer = await _requireReviewerProfile();

    final List<dynamic> rows = await _client
        .from(correctionTableName)
        .select()
        .eq('status', 'pending')
        .neq('user_id', reviewer.id)
        .order('created_at', ascending: true);

    final List<Map<String, dynamic>> requests = rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final Map<String, ApprovalEmployeeProfile> profiles =
        await _profilesForRequests(requests);
    final Map<String, Map<String, dynamic>> attendanceById =
        await _attendanceForCorrectionRequests(requests);

    return requests
        .map(
          (Map<String, dynamic> row) => _correctionApprovalFromMap(
            row,
            profiles[row['user_id'] as String],
            attendanceById[row['attendance_record_id'] as String?],
          ),
        )
        .toList(growable: false);
  }

  Future<List<CorrectionApprovalItem>>
  fetchReviewedCorrectionApprovals() async {
    final WorkPulseUserProfile reviewer = await _requireReviewerProfile();

    final List<dynamic> rows = await _client
        .from(correctionTableName)
        .select()
        .neq('status', 'pending')
        .neq('user_id', reviewer.id)
        .order('updated_at', ascending: false);

    final List<Map<String, dynamic>> requests = rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final Map<String, ApprovalEmployeeProfile> profiles =
        await _profilesForRequests(requests);
    final Map<String, Map<String, dynamic>> attendanceById =
        await _attendanceForCorrectionRequests(requests);

    return requests
        .map(
          (Map<String, dynamic> row) => _correctionApprovalFromMap(
            row,
            profiles[row['user_id'] as String],
            attendanceById[row['attendance_record_id'] as String?],
          ),
        )
        .toList(growable: false);
  }

  Future<void> approveLeave({
    required String requestId,
    String? reviewerNote,
  }) async {
    await _requireReviewerProfile();
    await _client.rpc('review_leave_request', params: <String, dynamic>{
      'p_request_id': requestId,
      'p_decision': 'approved',
      'p_note': _blankToNull(reviewerNote),
    });
  }

  Future<void> rejectLeave({
    required String requestId,
    String? reviewerNote,
  }) async {
    await _requireReviewerProfile();
    await _client.rpc('review_leave_request', params: <String, dynamic>{
      'p_request_id': requestId,
      'p_decision': 'rejected',
      'p_note': _blankToNull(reviewerNote),
    });
  }

  Future<void> approveCorrection({
    required CorrectionApprovalItem request,
    String? reviewerNote,
  }) async {
    final WorkPulseUserProfile reviewer = await _requireReviewerProfile();
    await _applyApprovedCorrection(request);
    await _updateRequestStatus(
      tableName: correctionTableName,
      requestId: request.id,
      nextStatus: 'approved',
      reviewerId: reviewer.id,
      reviewerNote: reviewerNote,
    );
  }

  Future<void> rejectCorrection({
    required CorrectionApprovalItem request,
    String? reviewerNote,
  }) async {
    final WorkPulseUserProfile reviewer = await _requireReviewerProfile();
    await _updateRequestStatus(
      tableName: correctionTableName,
      requestId: request.id,
      nextStatus: 'rejected',
      reviewerId: reviewer.id,
      reviewerNote: reviewerNote,
    );
    await _clearCorrectionPendingStatusIfNeeded(request);
  }

  Future<WorkPulseUserProfile> _requireReviewerProfile() async {
    final WorkPulseUserProfile? profile = await _authService
        .fetchCurrentProfile();
    if (profile == null) {
      throw StateError('No signed-in reviewer profile found.');
    }
    if (!profile.hasAnyRole(reviewerRoles)) {
      throw StateError('This account is not allowed to review requests.');
    }
    return profile;
  }

  Future<Map<String, ApprovalEmployeeProfile>> _profilesForRequests(
    List<Map<String, dynamic>> requests,
  ) async {
    final Set<String> userIds = requests
        .map((Map<String, dynamic> row) => row['user_id'] as String?)
        .whereType<String>()
        .toSet();
    if (userIds.isEmpty) {
      return <String, ApprovalEmployeeProfile>{};
    }

    final List<dynamic> rows = await _client
        .from(profilesTableName)
        .select('id, employee_id, full_name, email')
        .inFilter('id', userIds.toList());

    return <String, ApprovalEmployeeProfile>{
      for (final dynamic row in rows)
        (row as Map)['id'] as String: ApprovalEmployeeProfile.fromMap(
          Map<String, dynamic>.from(row),
        ),
    };
  }

  Future<Map<String, Map<String, dynamic>>> _attendanceForCorrectionRequests(
    List<Map<String, dynamic>> requests,
  ) async {
    final Set<String> attendanceIds = requests
        .map(
          (Map<String, dynamic> row) => row['attendance_record_id'] as String?,
        )
        .whereType<String>()
        .where((String id) => id.isNotEmpty)
        .toSet();
    if (attendanceIds.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    final List<dynamic> rows = await _client
        .from(attendanceTableName)
        .select('id, clock_in, clock_out, status')
        .inFilter('id', attendanceIds.toList());

    return <String, Map<String, dynamic>>{
      for (final dynamic row in rows)
        (row as Map)['id'] as String: Map<String, dynamic>.from(row),
    };
  }

  Future<void> _updateRequestStatus({
    required String tableName,
    required String requestId,
    required String nextStatus,
    required String reviewerId,
    required String? reviewerNote,
  }) async {
    final Map<String, dynamic> reviewPayload = <String, dynamic>{
      'status': nextStatus,
      'reviewed_by': reviewerId,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewer_note': _blankToNull(reviewerNote),
    };

    try {
      await _client
          .from(tableName)
          .update(reviewPayload)
          .eq('id', requestId)
          .eq('status', 'pending');
    } catch (error) {
      if (!_looksLikeMissingReviewColumns(error)) {
        rethrow;
      }
      await _client
          .from(tableName)
          .update(<String, dynamic>{'status': nextStatus})
          .eq('id', requestId)
          .eq('status', 'pending');
    }
  }

  Future<void> _applyApprovedCorrection(CorrectionApprovalItem request) async {
    if (request.attendanceRecordId.isEmpty) {
      return;
    }

    final DateTime? nextClockIn =
        request.correctedClockInAt ?? request.originalClockInAt;
    final DateTime? nextClockOut =
        request.correctedClockOutAt ?? request.originalClockOutAt;
    final String nextStatus = _attendanceStatusFor(
      workDate: request.affectedDate,
      clockInAt: nextClockIn,
      clockOutAt: nextClockOut,
    );

    await _client
        .from(attendanceTableName)
        .update(<String, dynamic>{
          'clock_in': nextClockIn?.toUtc().toIso8601String(),
          'clock_out': nextClockOut?.toUtc().toIso8601String(),
          'status': nextStatus,
        })
        .eq('id', request.attendanceRecordId);
  }

  Future<void> _clearCorrectionPendingStatusIfNeeded(
    CorrectionApprovalItem request,
  ) async {
    if (request.attendanceRecordId.isEmpty) {
      return;
    }

    final List<dynamic> remainingPendingRows = await _client
        .from(correctionTableName)
        .select('id')
        .eq('attendance_record_id', request.attendanceRecordId)
        .eq('status', 'pending');

    if (remainingPendingRows.isNotEmpty) {
      return;
    }

    final Map<String, dynamic>? attendanceRow = await _client
        .from(attendanceTableName)
        .select('id, work_date, clock_in, clock_out')
        .eq('id', request.attendanceRecordId)
        .maybeSingle();

    if (attendanceRow == null) {
      return;
    }

    final DateTime workDate = DateTime.parse(
      attendanceRow['work_date'] as String,
    );
    await _client
        .from(attendanceTableName)
        .update(<String, dynamic>{
          'status': _attendanceStatusFor(
            workDate: workDate,
            clockInAt: _parseDateTime(attendanceRow['clock_in']),
            clockOutAt: _parseDateTime(attendanceRow['clock_out']),
          ),
        })
        .eq('id', request.attendanceRecordId);
  }

  String _attendanceStatusFor({
    required DateTime workDate,
    required DateTime? clockInAt,
    required DateTime? clockOutAt,
  }) {
    if (clockInAt != null && clockOutAt != null) {
      return 'completed';
    }
    if (clockInAt != null) {
      final DateTime today = _dateOnly(DateTime.now());
      return _dateOnly(workDate).isBefore(today) ? 'missed_punch' : 'on_duty';
    }
    return _dateOnly(workDate).isBefore(_dateOnly(DateTime.now()))
        ? 'absent'
        : 'on_duty';
  }

  bool _looksLikeMissingReviewColumns(Object error) {
    final String message = error.toString().toLowerCase();
    return message.contains('reviewed_by') ||
        message.contains('reviewed_at') ||
        message.contains('reviewer_note');
  }

  String? _blankToNull(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class ApprovalCounts {
  const ApprovalCounts({
    required this.pendingLeaveCount,
    required this.pendingCorrectionCount,
  });

  final int pendingLeaveCount;
  final int pendingCorrectionCount;

  int get totalPending => pendingLeaveCount + pendingCorrectionCount;
}

class ApprovalEmployeeProfile {
  const ApprovalEmployeeProfile({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.email,
  });

  final String id;
  final String employeeId;
  final String fullName;
  final String email;

  factory ApprovalEmployeeProfile.fromMap(Map<String, dynamic> map) {
    return ApprovalEmployeeProfile(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
    );
  }
}

class LeaveApprovalItem {
  const LeaveApprovalItem({
    required this.id,
    required this.employee,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.reason,
    required this.submittedAt,
    required this.status,
    this.reviewedAt,
    this.reviewerNote,
    this.workflowStage,
    this.escalatedAt,
    this.supervisorLockedAt,
  });

  final String id;
  final ApprovalEmployeeProfile employee;
  final LeaveType type;
  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;
  final String reason;
  final DateTime submittedAt;
  final LeaveRequestStatus status;
  final DateTime? reviewedAt;
  final String? reviewerNote;
  final String? workflowStage;
  final DateTime? escalatedAt;
  final DateTime? supervisorLockedAt;

  bool get isOverdue =>
      status == LeaveRequestStatus.pendingApproval &&
      !DateTime.now().isBefore(startDate);

  String get approvalOwnerLabel => workflowStage == 'hr_pending'
      ? 'Awaiting HR approval'
      : escalatedAt != null
      ? 'Escalated to HR'
      : 'Awaiting supervisor approval';
}

class CorrectionApprovalItem {
  const CorrectionApprovalItem({
    required this.id,
    required this.employee,
    required this.attendanceRecordId,
    required this.affectedDate,
    required this.issueSummary,
    required this.correctionType,
    required this.reason,
    required this.submittedAt,
    required this.status,
    this.correctedClockInAt,
    this.correctedClockOutAt,
    this.originalClockInAt,
    this.originalClockOutAt,
    this.reviewedAt,
    this.reviewerNote,
  });

  final String id;
  final ApprovalEmployeeProfile employee;
  final String attendanceRecordId;
  final DateTime affectedDate;
  final String issueSummary;
  final CorrectionType correctionType;
  final String reason;
  final DateTime submittedAt;
  final CorrectionRequestApprovalStatus status;
  final DateTime? correctedClockInAt;
  final DateTime? correctedClockOutAt;
  final DateTime? originalClockInAt;
  final DateTime? originalClockOutAt;
  final DateTime? reviewedAt;
  final String? reviewerNote;
}

enum CorrectionRequestApprovalStatus { pending, approved, rejected }

LeaveApprovalItem _leaveApprovalFromMap(
  Map<String, dynamic> map,
  ApprovalEmployeeProfile? employee,
) {
  final DateTime startDate = _dateOnly(
    DateTime.parse(map['start_date'] as String),
  );
  final DateTime endDate = _dateOnly(DateTime.parse(map['end_date'] as String));

  return LeaveApprovalItem(
    id: map['id'] as String,
    employee: employee ?? _unknownEmployee(map['user_id'] as String),
    type: _leaveTypeFromValue(map['leave_type'] as String),
    startDate: startDate,
    endDate: endDate,
    durationDays: (map['duration_days'] as num).toInt(),
    reason: (map['reason'] as String?) ?? '',
    submittedAt: DateTime.parse(map['created_at'] as String).toLocal(),
    status: _leaveStatusFromValue(map['status'] as String),
    reviewedAt: _parseDateTime(map['reviewed_at']),
    reviewerNote: map['reviewer_note'] as String?,
    workflowStage: map['workflow_stage'] as String?,
    escalatedAt: _parseDateTime(map['escalated_at']),
    supervisorLockedAt: _parseDateTime(map['supervisor_locked_at']),
  );
}

CorrectionApprovalItem _correctionApprovalFromMap(
  Map<String, dynamic> map,
  ApprovalEmployeeProfile? employee,
  Map<String, dynamic>? attendanceRow,
) {
  final DateTime affectedDate = _dateOnly(
    DateTime.parse(map['work_date'] as String),
  );
  final CorrectionType correctionType = _correctionTypeFromValue(
    map['correction_type'] as String,
  );

  return CorrectionApprovalItem(
    id: map['id'] as String,
    employee: employee ?? _unknownEmployee(map['user_id'] as String),
    attendanceRecordId: (map['attendance_record_id'] as String?) ?? '',
    affectedDate: affectedDate,
    issueSummary: _issueSummaryFor(
      affectedDate: affectedDate,
      correctionType: correctionType,
    ),
    correctionType: correctionType,
    reason: map['reason'] as String,
    submittedAt: DateTime.parse(map['created_at'] as String).toLocal(),
    status: _correctionStatusFromValue(map['status'] as String),
    correctedClockInAt: _parseDateTime(map['corrected_clock_in']),
    correctedClockOutAt: _parseDateTime(map['corrected_clock_out']),
    originalClockInAt: _parseDateTime(attendanceRow?['clock_in']),
    originalClockOutAt: _parseDateTime(attendanceRow?['clock_out']),
    reviewedAt: _parseDateTime(map['reviewed_at']),
    reviewerNote: map['reviewer_note'] as String?,
  );
}

ApprovalEmployeeProfile _unknownEmployee(String id) {
  return ApprovalEmployeeProfile(
    id: id,
    employeeId: 'Unknown',
    fullName: 'Unknown Employee',
    email: '',
  );
}

LeaveType _leaveTypeFromValue(String value) {
  switch (value) {
    case 'annual':
      return LeaveType.annualLeave;
    case 'sick':
      return LeaveType.sickLeave;
    case 'other':
      return LeaveType.other;
    default:
      throw ArgumentError('Unsupported leave type: $value');
  }
}

LeaveRequestStatus _leaveStatusFromValue(String value) {
  switch (value) {
    case 'pending':
      return LeaveRequestStatus.pendingApproval;
    case 'approved':
      return LeaveRequestStatus.approved;
    case 'rejected':
      return LeaveRequestStatus.rejected;
    default:
      throw ArgumentError('Unsupported leave request status: $value');
  }
}

CorrectionRequestApprovalStatus _correctionStatusFromValue(String value) {
  switch (value) {
    case 'pending':
      return CorrectionRequestApprovalStatus.pending;
    case 'approved':
      return CorrectionRequestApprovalStatus.approved;
    case 'rejected':
      return CorrectionRequestApprovalStatus.rejected;
    default:
      throw ArgumentError('Unsupported correction request status: $value');
  }
}

CorrectionType _correctionTypeFromValue(String value) {
  switch (value) {
    case 'clock_in':
      return CorrectionType.clockIn;
    case 'clock_out':
      return CorrectionType.clockOut;
    case 'both':
      return CorrectionType.both;
    default:
      throw ArgumentError('Unsupported correction type: $value');
  }
}

String _issueSummaryFor({
  required DateTime affectedDate,
  required CorrectionType correctionType,
}) {
  switch (correctionType) {
    case CorrectionType.clockIn:
      return 'Missing Clock In for ${dateLabel(affectedDate)}';
    case CorrectionType.clockOut:
      return 'Missing Clock Out for ${dateLabel(affectedDate)}';
    case CorrectionType.both:
      return 'Missing Clock In & Clock Out for ${dateLabel(affectedDate)}';
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value as String).toLocal();
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}
