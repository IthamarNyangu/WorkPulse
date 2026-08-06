import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/work_calendar_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveService {
  LeaveService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client,
      _workCalendarService = WorkCalendarService(
        client: client ?? SupabaseBootstrap.client,
      );

  static const String tableName = 'leave_requests';
  static const String attendanceTableName = 'attendance_records';
  static const int defaultAnnualLeaveEntitlementDays = 30;

  final SupabaseClient _client;
  final WorkCalendarService _workCalendarService;

  Future<int> countLeaveWorkingDays({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final dynamic result = await _client.rpc(
        'count_my_leave_working_days',
        params: <String, dynamic>{
          'p_start_date': _dateOnlyLabel(startDate),
          'p_end_date': _dateOnlyLabel(endDate),
        },
      );
      return (result as num).toInt();
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202' &&
          !error.message.toLowerCase().contains(
            'count_my_leave_working_days',
          )) {
        rethrow;
      }
      return _workCalendarService.countWorkingDays(
        startDate: startDate,
        endDate: endDate,
      );
    }
  }

  Future<List<LeaveRequest>> fetchLeaveRequests() async {
    final String userId = _requireCurrentUserId();

    final List<dynamic> rows = await _client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .order('start_date', ascending: true)
        .order('created_at', ascending: false);

    final List<LeaveRequest> requests = rows
        .map(
          (dynamic row) =>
              _leaveRequestFromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);

    final DateTime today = _dateOnly(DateTime.now());
    final List<LeaveRequest> upcomingOrPending = requests
        .where(
          (LeaveRequest request) =>
              !request.endDate.isBefore(today) ||
              request.status == LeaveRequestStatus.pendingApproval,
        )
        .toList();
    final List<LeaveRequest> past = requests
        .where(
          (LeaveRequest request) =>
              request.endDate.isBefore(today) &&
              request.status != LeaveRequestStatus.pendingApproval,
        )
        .toList();

    upcomingOrPending.sort(
      (LeaveRequest a, LeaveRequest b) => a.startDate.compareTo(b.startDate),
    );
    past.sort(
      (LeaveRequest a, LeaveRequest b) => b.startDate.compareTo(a.startDate),
    );

    return <LeaveRequest>[...upcomingOrPending, ...past];
  }

  Future<LeaveRequest?> fetchLeaveRequestById(String id) async {
    final String userId = _requireCurrentUserId();

    final Map<String, dynamic>? row = await _client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .eq('id', id)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return _leaveRequestFromMap(row);
  }

  Future<int> fetchPendingLeaveRequestCount() async {
    final String userId = _requireCurrentUserId();

    final List<dynamic> rows = await _client
        .from(tableName)
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'pending');

    return rows.length;
  }

  Future<AnnualLeaveBalance> fetchAnnualLeaveBalance({
    int totalDays = defaultAnnualLeaveEntitlementDays,
  }) async {
    final String userId = _requireCurrentUserId();

    final List<dynamic> rows = await _client
        .from(tableName)
        .select('duration_days, status')
        .eq('user_id', userId)
        .eq('leave_type', 'annual');

    int usedDays = 0;
    int pendingDays = 0;
    for (final dynamic row in rows) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(row as Map);
      final int durationDays = (map['duration_days'] as num).toInt();
      switch (map['status'] as String) {
        case 'approved':
          usedDays += durationDays;
          break;
        case 'pending':
          pendingDays += durationDays;
          break;
      }
    }

    return AnnualLeaveBalance(
      totalDays: totalDays,
      usedDays: usedDays,
      pendingDays: pendingDays,
    );
  }

  Future<LeaveRequest> submitLeaveRequest({
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final String userId = _requireCurrentUserId();
    final DateTime safeStartDate = _dateOnly(startDate);
    final DateTime safeEndDate = _dateOnly(endDate);
    final int durationDays = await _validatedWorkingDayDuration(
      startDate: safeStartDate,
      endDate: safeEndDate,
    );
    await _throwIfAttendanceExistsForRange(
      userId: userId,
      startDate: safeStartDate,
      endDate: safeEndDate,
    );

    final Map<String, dynamic> row = await _client
        .from(tableName)
        .insert(<String, dynamic>{
          'user_id': userId,
          'leave_type': _leaveTypeValue(type),
          'start_date': _dateOnlyLabel(safeStartDate),
          'end_date': _dateOnlyLabel(safeEndDate),
          'duration_days': durationDays,
          'reason': reason,
          'status': 'pending',
        })
        .select()
        .single();

    return _leaveRequestFromMap(row);
  }

  Future<LeaveRequest> updatePendingLeaveRequest({
    required String requestId,
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final String userId = _requireCurrentUserId();
    final DateTime safeStartDate = _dateOnly(startDate);
    final DateTime safeEndDate = _dateOnly(endDate);
    final int durationDays = await _validatedWorkingDayDuration(
      startDate: safeStartDate,
      endDate: safeEndDate,
    );
    await _throwIfAttendanceExistsForRange(
      userId: userId,
      startDate: safeStartDate,
      endDate: safeEndDate,
    );

    final Map<String, dynamic> row = await _client
        .from(tableName)
        .update(<String, dynamic>{
          'leave_type': _leaveTypeValue(type),
          'start_date': _dateOnlyLabel(safeStartDate),
          'end_date': _dateOnlyLabel(safeEndDate),
          'duration_days': durationDays,
          'reason': reason,
        })
        .eq('id', requestId)
        .eq('user_id', userId)
        .eq('status', 'pending')
        .select()
        .single();

    return _leaveRequestFromMap(row);
  }

  Future<void> deletePendingLeaveRequest({required String requestId}) async {
    final String userId = _requireCurrentUserId();

    await _client
        .from(tableName)
        .delete()
        .eq('id', requestId)
        .eq('user_id', userId)
        .eq('status', 'pending');
  }

  String _requireCurrentUserId() {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('No signed-in user found.');
    }
    return userId;
  }

  Future<int> _validatedWorkingDayDuration({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final int durationDays = await countLeaveWorkingDays(
      startDate: startDate,
      endDate: endDate,
    );
    if (durationDays < 1) {
      throw StateError(
        'The selected range contains no working days. Weekends and public holidays do not require leave.',
      );
    }
    return durationDays;
  }

  Future<void> _throwIfAttendanceExistsForRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final List<dynamic> rows = await _client
        .from(attendanceTableName)
        .select('work_date, status, clock_in, clock_out')
        .eq('user_id', userId)
        .gte('work_date', _dateOnlyLabel(startDate))
        .lte('work_date', _dateOnlyLabel(endDate));

    final List<DateTime> conflictDates = rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .where(_hasAttendanceActivity)
        .map(
          (Map<String, dynamic> row) =>
              _dateOnly(DateTime.parse(row['work_date'] as String)),
        )
        .toList(growable: false);

    if (conflictDates.isEmpty) {
      return;
    }

    conflictDates.sort();
    throw StateError(
      'Leave cannot be requested for dates with attendance activity: '
      '${_conflictDatesLabel(conflictDates)}.',
    );
  }

  bool _hasAttendanceActivity(Map<String, dynamic> row) {
    if (row['clock_in'] != null || row['clock_out'] != null) {
      return true;
    }

    switch (row['status'] as String?) {
      case 'completed':
      case 'on_duty':
      case 'missed_punch':
      case 'correction_pending':
        return true;
      default:
        return false;
    }
  }

  String _conflictDatesLabel(List<DateTime> dates) {
    if (dates.length == 1) {
      return dateLabel(dates.first);
    }
    if (dates.length == 2) {
      return '${dateLabel(dates.first)} and ${dateLabel(dates.last)}';
    }
    return '${dateLabel(dates.first)} and ${dates.length - 1} more dates';
  }
}

class AnnualLeaveBalance {
  const AnnualLeaveBalance({
    required this.totalDays,
    required this.usedDays,
    required this.pendingDays,
  });

  final int totalDays;
  final int usedDays;
  final int pendingDays;

  int get remainingDays {
    final int remaining = totalDays - usedDays;
    return remaining < 0 ? 0 : remaining;
  }

  int get projectedRemainingDays {
    final int projected = remainingDays - pendingDays;
    return projected < 0 ? 0 : projected;
  }
}

LeaveRequest _leaveRequestFromMap(Map<String, dynamic> map) {
  return LeaveRequest(
    id: map['id'] as String,
    type: _leaveTypeFromValue(map['leave_type'] as String),
    startDate: _dateOnly(DateTime.parse(map['start_date'] as String)),
    endDate: _dateOnly(DateTime.parse(map['end_date'] as String)),
    durationDays: (map['duration_days'] as num?)?.toInt(),
    reason: (map['reason'] as String?) ?? '',
    status: _leaveStatusFromValue(map['status'] as String),
    submittedAt: DateTime.parse(map['created_at'] as String).toLocal(),
    reviewerNote: map['reviewer_note'] as String?,
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

String _leaveTypeValue(LeaveType type) {
  switch (type) {
    case LeaveType.annualLeave:
      return 'annual';
    case LeaveType.sickLeave:
      return 'sick';
    case LeaveType.other:
      return 'other';
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

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

String _dateOnlyLabel(DateTime dateTime) {
  final DateTime localDate = _dateOnly(dateTime);
  final String year = localDate.year.toString().padLeft(4, '0');
  final String month = localDate.month.toString().padLeft(2, '0');
  final String day = localDate.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
