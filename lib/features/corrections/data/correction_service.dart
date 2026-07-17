import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CorrectionService {
  CorrectionService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  static const String tableName = 'correction_requests';
  static const String attendanceTableName = 'attendance_records';

  final SupabaseClient _client;

  Future<List<AttendanceRecord>> fetchMissedPunchRecords() async {
    final String userId = _requireCurrentUserId();
    await AttendanceService(client: _client).syncAttendanceClassifications();

    final List<dynamic> rows = await _client
        .from(attendanceTableName)
        .select()
        .eq('user_id', userId)
        .eq('status', 'missed_punch')
        .order('work_date', ascending: true)
        .order('created_at', ascending: true);

    return rows
        .map(
          (dynamic row) => SupabaseAttendanceRecord.fromMap(
            Map<String, dynamic>.from(row as Map),
          ).toHistoryRecord(),
        )
        .toList(growable: false);
  }

  Future<int> fetchMissedPunchCount() async {
    final String userId = _requireCurrentUserId();
    await AttendanceService(client: _client).syncAttendanceClassifications();

    final List<dynamic> rows = await _client
        .from(attendanceTableName)
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'missed_punch');

    return rows.length;
  }

  Future<List<CorrectionRequest>> fetchPendingCorrectionRequests() async {
    final String userId = _requireCurrentUserId();

    final List<dynamic> rows = await _client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .order('work_date', ascending: true)
        .order('created_at', ascending: false);

    return rows
        .map(
          (dynamic row) =>
              _correctionRequestFromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<int> fetchPendingCorrectionRequestCount() async {
    final String userId = _requireCurrentUserId();

    final List<dynamic> rows = await _client
        .from(tableName)
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'pending');

    return rows.length;
  }

  Future<CorrectionRequest?> fetchCorrectionRequestById(String id) async {
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

    return _correctionRequestFromMap(row);
  }

  Future<CorrectionRequest> submitCorrectionRequest({
    required String attendanceRecordId,
    required DateTime affectedDate,
    required CorrectionType correctionType,
    required String reason,
    String? correctedClockInTime,
    String? correctedClockOutTime,
  }) async {
    final String userId = _requireCurrentUserId();

    final Map<String, dynamic> row = await _client
        .from(tableName)
        .insert(<String, dynamic>{
          'user_id': userId,
          'attendance_record_id': attendanceRecordId,
          'work_date': _dateOnlyLabel(affectedDate),
          'correction_type': _correctionTypeValue(correctionType),
          'corrected_clock_in': _correctedTimeValue(
            affectedDate,
            correctedClockInTime,
          ),
          'corrected_clock_out': _correctedTimeValue(
            affectedDate,
            correctedClockOutTime,
          ),
          'reason': reason,
          'status': 'pending',
        })
        .select()
        .single();

    await _markAttendanceCorrectionPending(
      userId: userId,
      attendanceRecordId: attendanceRecordId,
    );

    return _correctionRequestFromMap(row);
  }

  Future<CorrectionRequest> updatePendingCorrectionRequest({
    required String requestId,
    required String attendanceRecordId,
    required DateTime affectedDate,
    required CorrectionType correctionType,
    required String reason,
    String? correctedClockInTime,
    String? correctedClockOutTime,
  }) async {
    final String userId = _requireCurrentUserId();

    final Map<String, dynamic> row = await _client
        .from(tableName)
        .update(<String, dynamic>{
          'attendance_record_id': attendanceRecordId,
          'work_date': _dateOnlyLabel(affectedDate),
          'correction_type': _correctionTypeValue(correctionType),
          'corrected_clock_in': _correctedTimeValue(
            affectedDate,
            correctedClockInTime,
          ),
          'corrected_clock_out': _correctedTimeValue(
            affectedDate,
            correctedClockOutTime,
          ),
          'reason': reason,
        })
        .eq('id', requestId)
        .eq('user_id', userId)
        .eq('status', 'pending')
        .select()
        .single();

    await _markAttendanceCorrectionPending(
      userId: userId,
      attendanceRecordId: attendanceRecordId,
    );

    return _correctionRequestFromMap(row);
  }

  Future<void> _markAttendanceCorrectionPending({
    required String userId,
    required String attendanceRecordId,
  }) async {
    if (attendanceRecordId.isEmpty) {
      return;
    }

    await _client
        .from(attendanceTableName)
        .update(<String, dynamic>{'status': 'correction_pending'})
        .eq('id', attendanceRecordId)
        .eq('user_id', userId);
  }

  String _requireCurrentUserId() {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('No signed-in user found.');
    }
    return userId;
  }
}

CorrectionRequest _correctionRequestFromMap(Map<String, dynamic> map) {
  final DateTime affectedDate = _dateOnly(
    DateTime.parse(map['work_date'] as String),
  );
  final CorrectionType correctionType = _correctionTypeFromValue(
    map['correction_type'] as String,
  );

  return CorrectionRequest(
    id: map['id'] as String,
    attendanceRecordId: (map['attendance_record_id'] as String?) ?? '',
    affectedDate: affectedDate,
    issueSummary: _issueSummaryFor(
      affectedDate: affectedDate,
      correctionType: correctionType,
    ),
    correctionType: correctionType,
    reason: map['reason'] as String,
    status: CorrectionRequestStatus.pending,
    submittedAt: DateTime.parse(map['created_at'] as String).toLocal(),
    correctedClockInTime: _timeLabelOrNull(map['corrected_clock_in']),
    correctedClockOutTime: _timeLabelOrNull(map['corrected_clock_out']),
  );
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

String _correctionTypeValue(CorrectionType type) {
  switch (type) {
    case CorrectionType.clockIn:
      return 'clock_in';
    case CorrectionType.clockOut:
      return 'clock_out';
    case CorrectionType.both:
      return 'both';
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

String? _correctedTimeValue(DateTime date, String? timeText) {
  final DateTime? correctedTime = _correctedDateTime(date, timeText);
  return correctedTime?.toUtc().toIso8601String();
}

DateTime? _correctedDateTime(DateTime date, String? timeText) {
  if (timeText == null || timeText.trim().isEmpty) {
    return null;
  }

  final String text = timeText.trim().toUpperCase();
  final RegExp twentyFourHourExpression = RegExp(r'^(\d{1,2}):(\d{2})$');
  final Match? twentyFourHourMatch = twentyFourHourExpression.firstMatch(text);
  if (twentyFourHourMatch != null) {
    final int hour = int.parse(twentyFourHourMatch.group(1)!);
    final int minute = int.parse(twentyFourHourMatch.group(2)!);
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  final RegExp twelveHourExpression = RegExp(r'^(\d{1,2}):(\d{2})\s?(AM|PM)$');
  final Match? twelveHourMatch = twelveHourExpression.firstMatch(text);
  if (twelveHourMatch == null) {
    return null;
  }

  int hour = int.parse(twelveHourMatch.group(1)!);
  final int minute = int.parse(twelveHourMatch.group(2)!);
  final String period = twelveHourMatch.group(3)!;

  if (hour < 1 || hour > 12 || minute < 0 || minute > 59) {
    return null;
  }

  if (period == 'PM' && hour != 12) {
    hour += 12;
  }
  if (period == 'AM' && hour == 12) {
    hour = 0;
  }

  return DateTime(date.year, date.month, date.day, hour, minute);
}

String? _timeLabelOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return timeLabel(DateTime.parse(value as String).toLocal());
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
