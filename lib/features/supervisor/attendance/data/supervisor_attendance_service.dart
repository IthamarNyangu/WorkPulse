import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/features/attendance/location/office_location_service.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SupervisorAttendanceStatus {
  noClockIn,
  onDuty,
  completed,
  missedPunch,
  correctionPending,
  leavePending,
  onLeave,
  absent,
}

extension SupervisorAttendanceStatusLabels on SupervisorAttendanceStatus {
  String get label {
    switch (this) {
      case SupervisorAttendanceStatus.noClockIn:
        return 'No Clock In';
      case SupervisorAttendanceStatus.onDuty:
        return 'On Duty';
      case SupervisorAttendanceStatus.completed:
        return 'Completed';
      case SupervisorAttendanceStatus.missedPunch:
        return 'Missed Punch';
      case SupervisorAttendanceStatus.correctionPending:
        return 'Correction Pending';
      case SupervisorAttendanceStatus.leavePending:
        return 'Leave Pending';
      case SupervisorAttendanceStatus.onLeave:
        return 'On Leave';
      case SupervisorAttendanceStatus.absent:
        return 'Absent';
    }
  }
}

class SupervisorAttendanceDay {
  const SupervisorAttendanceDay({
    required this.date,
    required this.summary,
    required this.records,
  });

  final DateTime date;
  final SupervisorAttendanceSummary summary;
  final List<SupervisorAttendanceEmployeeRecord> records;
}

class SupervisorAttendanceSummary {
  const SupervisorAttendanceSummary({
    required this.totalEmployees,
    required this.clockedIn,
    required this.clockedOut,
    required this.absent,
    required this.onLeave,
    required this.locationExceptions,
  });

  final int totalEmployees;
  final int clockedIn;
  final int clockedOut;
  final int absent;
  final int onLeave;
  final int locationExceptions;
}

class SupervisorAttendanceEmployeeRecord {
  const SupervisorAttendanceEmployeeRecord({
    required this.employeeId,
    required this.employeeName,
    required this.email,
    required this.status,
    required this.date,
    this.department,
    this.attendanceRecordId,
    this.clockInAt,
    this.clockOutAt,
    this.workedDuration,
    this.clockInComment,
    this.clockOutComment,
    this.clockInLocation,
    this.clockOutLocation,
  });

  final String employeeId;
  final String employeeName;
  final String email;
  final String? department;
  final SupervisorAttendanceStatus status;
  final DateTime date;
  final String? attendanceRecordId;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final Duration? workedDuration;
  final String? clockInComment;
  final String? clockOutComment;
  final ClockLocationSnapshot? clockInLocation;
  final ClockLocationSnapshot? clockOutLocation;

  String get clockInLabel => clockInAt == null ? '--' : timeLabel(clockInAt!);
  String get clockOutLabel =>
      clockOutAt == null ? '--' : timeLabel(clockOutAt!);
  String get workHoursLabel =>
      workedDuration == null ? '--' : durationLabel(workedDuration!);
  bool get hasClockedIn => clockInAt != null;
  bool get hasClockedOut => clockOutAt != null;
  bool get hasLocationException =>
      _isLocationException(clockInLocation) ||
      _isLocationException(clockOutLocation);

  String? get officeDisplayName {
    return clockInLocation?.officeDisplayName ??
        clockOutLocation?.officeDisplayName;
  }

  static bool _isLocationException(ClockLocationSnapshot? snapshot) {
    if (snapshot == null) {
      return false;
    }
    return snapshot.status != ClockLocationStatus.insideOffice;
  }
}

class SupervisorAttendanceService {
  SupervisorAttendanceService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client,
      _authService = AuthService(client: client ?? SupabaseBootstrap.client),
      _officeLocationService = OfficeLocationService(
        client: client ?? SupabaseBootstrap.client,
      );

  static const String profilesTableName = 'profiles';
  static const String attendanceTableName = 'attendance_records';
  static const String leaveTableName = 'leave_requests';
  static const Set<String> reviewerRoles = <String>{
    'supervisor',
    'hr',
    'admin',
  };

  final SupabaseClient _client;
  final AuthService _authService;
  final OfficeLocationService _officeLocationService;

  Future<SupervisorAttendanceDay> fetchAttendanceDay(DateTime date) async {
    final WorkPulseUserProfile reviewer = await _requireReviewerProfile();
    if (!reviewerRoles.contains(reviewer.role)) {
      throw StateError(
        'Only supervisors, HR, and admins can view the attendance dashboard.',
      );
    }

    final DateTime selectedDate = _dateOnly(date);
    final String selectedDateLabel = _dateOnlyLabel(selectedDate);

    final List<_DashboardEmployee> employees = await _fetchEmployees();
    final List<Map<String, dynamic>> attendanceRows =
        await _fetchAttendanceRows(selectedDateLabel);
    final List<Map<String, dynamic>> leaveRows = await _fetchLeaveRows(
      selectedDateLabel,
    );
    final Map<String, String> officeNamesById = await _officeNamesById();

    final Map<String, SupabaseAttendanceRecord> attendanceByUserId =
        <String, SupabaseAttendanceRecord>{
          for (final Map<String, dynamic> row in attendanceRows)
            row['user_id'] as String: SupabaseAttendanceRecord.fromMap(row),
        };

    final Map<String, String> leaveStatusByUserId = _leaveStatusByUserId(
      leaveRows,
    );

    final List<SupervisorAttendanceEmployeeRecord> records =
        employees
            .map(
              (_DashboardEmployee employee) => _recordForEmployee(
                employee: employee,
                date: selectedDate,
                attendance: attendanceByUserId[employee.id],
                leaveStatus: leaveStatusByUserId[employee.id],
                officeNamesById: officeNamesById,
              ),
            )
            .toList(growable: false)
          ..sort(
            (
              SupervisorAttendanceEmployeeRecord a,
              SupervisorAttendanceEmployeeRecord b,
            ) => a.employeeName.compareTo(b.employeeName),
          );

    return SupervisorAttendanceDay(
      date: selectedDate,
      records: records,
      summary: _summaryFor(records),
    );
  }

  Future<WorkPulseUserProfile> _requireReviewerProfile() async {
    final WorkPulseUserProfile? profile = await _authService
        .fetchCurrentProfile();
    if (profile == null) {
      throw StateError('No active WorkPulse profile found.');
    }
    return profile;
  }

  Future<List<_DashboardEmployee>> _fetchEmployees() async {
    final List<dynamic> rows = await _client
        .from(profilesTableName)
        .select('id, employee_id, full_name, email, department, role')
        .eq('role', 'employee')
        .order('full_name', ascending: true);

    return rows
        .map(
          (dynamic row) =>
              _DashboardEmployee.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceRows(
    String dateLabel,
  ) async {
    final List<dynamic> rows = await _client
        .from(attendanceTableName)
        .select()
        .eq('work_date', dateLabel);

    return rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchLeaveRows(String dateLabel) async {
    final List<dynamic> rows = await _client
        .from(leaveTableName)
        .select('user_id, status, start_date, end_date')
        .lte('start_date', dateLabel)
        .gte('end_date', dateLabel);

    return rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, String>> _officeNamesById() async {
    final List<OfficeLocation> offices = await _officeLocationService
        .fetchOfficeLocations();
    return <String, String>{
      for (final OfficeLocation office in offices) office.id: office.officeName,
    };
  }

  Map<String, String> _leaveStatusByUserId(List<Map<String, dynamic>> rows) {
    final Map<String, String> statuses = <String, String>{};
    for (final Map<String, dynamic> row in rows) {
      final String? userId = row['user_id'] as String?;
      final String? status = row['status'] as String?;
      if (userId == null || status == null || status == 'rejected') {
        continue;
      }
      if (status == 'approved') {
        statuses[userId] = status;
        continue;
      }
      statuses.putIfAbsent(userId, () => status);
    }
    return statuses;
  }

  SupervisorAttendanceEmployeeRecord _recordForEmployee({
    required _DashboardEmployee employee,
    required DateTime date,
    required SupabaseAttendanceRecord? attendance,
    required String? leaveStatus,
    required Map<String, String> officeNamesById,
  }) {
    if (attendance == null) {
      return SupervisorAttendanceEmployeeRecord(
        employeeId: employee.employeeId,
        employeeName: employee.fullName,
        email: employee.email,
        department: employee.department,
        date: date,
        status: _statusWithoutAttendance(date: date, leaveStatus: leaveStatus),
      );
    }

    return SupervisorAttendanceEmployeeRecord(
      employeeId: employee.employeeId,
      employeeName: employee.fullName,
      email: employee.email,
      department: employee.department,
      date: date,
      attendanceRecordId: attendance.id,
      status: _statusFromAttendance(attendance.status),
      clockInAt: attendance.clockInAt,
      clockOutAt: attendance.clockOutAt,
      workedDuration: _workedDuration(attendance),
      clockInComment: attendance.clockInComment,
      clockOutComment: attendance.clockOutComment,
      clockInLocation: _locationSnapshot(
        latitude: attendance.clockInLatitude,
        longitude: attendance.clockInLongitude,
        accuracyMeters: attendance.clockInAccuracyMeters,
        isInsideGeofence: attendance.clockInInsideGeofence,
        locationStatus: attendance.clockInLocationStatus,
        verifiedOfficeLocationId: attendance.clockInVerifiedOfficeLocationId,
        verifiedOfficeName:
            officeNamesById[attendance.clockInVerifiedOfficeLocationId],
        nearestOfficeLocationId: attendance.clockInNearestOfficeLocationId,
        nearestOfficeName:
            officeNamesById[attendance.clockInNearestOfficeLocationId],
        distanceMeters: attendance.clockInDistanceMeters,
        geofenceRadiusMeters: attendance.clockInGeofenceRadiusMeters,
      ),
      clockOutLocation: _locationSnapshot(
        latitude: attendance.clockOutLatitude,
        longitude: attendance.clockOutLongitude,
        accuracyMeters: attendance.clockOutAccuracyMeters,
        isInsideGeofence: attendance.clockOutInsideGeofence,
        locationStatus: attendance.clockOutLocationStatus,
        verifiedOfficeLocationId: attendance.clockOutVerifiedOfficeLocationId,
        verifiedOfficeName:
            officeNamesById[attendance.clockOutVerifiedOfficeLocationId],
        nearestOfficeLocationId: attendance.clockOutNearestOfficeLocationId,
        nearestOfficeName:
            officeNamesById[attendance.clockOutNearestOfficeLocationId],
        distanceMeters: attendance.clockOutDistanceMeters,
        geofenceRadiusMeters: attendance.clockOutGeofenceRadiusMeters,
      ),
    );
  }

  SupervisorAttendanceStatus _statusWithoutAttendance({
    required DateTime date,
    required String? leaveStatus,
  }) {
    if (leaveStatus == 'approved') {
      return SupervisorAttendanceStatus.onLeave;
    }
    if (leaveStatus == 'pending') {
      return SupervisorAttendanceStatus.leavePending;
    }
    final DateTime today = _dateOnly(DateTime.now());
    if (date.isBefore(today) && _isWorkday(date)) {
      return SupervisorAttendanceStatus.absent;
    }
    return SupervisorAttendanceStatus.noClockIn;
  }

  SupervisorAttendanceStatus _statusFromAttendance(String? status) {
    switch (status) {
      case 'on_duty':
        return SupervisorAttendanceStatus.onDuty;
      case 'completed':
        return SupervisorAttendanceStatus.completed;
      case 'missed_punch':
        return SupervisorAttendanceStatus.missedPunch;
      case 'correction_pending':
        return SupervisorAttendanceStatus.correctionPending;
      case 'leave_pending':
        return SupervisorAttendanceStatus.leavePending;
      case 'on_leave':
        return SupervisorAttendanceStatus.onLeave;
      case 'absent':
        return SupervisorAttendanceStatus.absent;
      default:
        return SupervisorAttendanceStatus.noClockIn;
    }
  }

  Duration? _workedDuration(SupabaseAttendanceRecord attendance) {
    if (attendance.clockInAt == null) {
      return null;
    }
    if (attendance.clockOutAt != null &&
        !attendance.clockOutAt!.isBefore(attendance.clockInAt!)) {
      return attendance.clockOutAt!.difference(attendance.clockInAt!);
    }
    if (attendance.status == 'on_duty') {
      return DateTime.now().difference(attendance.clockInAt!);
    }
    return null;
  }

  SupervisorAttendanceSummary _summaryFor(
    List<SupervisorAttendanceEmployeeRecord> records,
  ) {
    return SupervisorAttendanceSummary(
      totalEmployees: records.length,
      clockedIn: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) => record.hasClockedIn,
          )
          .length,
      clockedOut: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) => record.hasClockedOut,
          )
          .length,
      absent: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) =>
                record.status == SupervisorAttendanceStatus.absent,
          )
          .length,
      onLeave: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) =>
                record.status == SupervisorAttendanceStatus.onLeave,
          )
          .length,
      locationExceptions: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) =>
                record.hasLocationException,
          )
          .length,
    );
  }

  bool _isWorkday(DateTime date) {
    return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
  }

  DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  String _dateOnlyLabel(DateTime dateTime) {
    final DateTime localDate = _dateOnly(dateTime.toLocal());
    final String year = localDate.year.toString().padLeft(4, '0');
    final String month = localDate.month.toString().padLeft(2, '0');
    final String day = localDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _DashboardEmployee {
  const _DashboardEmployee({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.email,
    this.department,
  });

  final String id;
  final String employeeId;
  final String fullName;
  final String email;
  final String? department;

  factory _DashboardEmployee.fromMap(Map<String, dynamic> map) {
    return _DashboardEmployee(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      department: map['department'] as String?,
    );
  }
}

ClockLocationSnapshot? _locationSnapshot({
  required double? latitude,
  required double? longitude,
  required double? accuracyMeters,
  required bool? isInsideGeofence,
  required String? locationStatus,
  required String? verifiedOfficeLocationId,
  required String? verifiedOfficeName,
  required String? nearestOfficeLocationId,
  required String? nearestOfficeName,
  required double? distanceMeters,
  required double? geofenceRadiusMeters,
}) {
  if (latitude == null || longitude == null) {
    if (locationStatus == null && isInsideGeofence == null) {
      return null;
    }

    final ClockLocationStatus status = locationStatus == null
        ? ((isInsideGeofence ?? false)
              ? ClockLocationStatus.insideOffice
              : ClockLocationStatus.locationUnavailable)
        : ClockLocationStatusLabels.fromDbValue(locationStatus);

    return ClockLocationSnapshot(
      coordinates: 'Not captured',
      accuracyMeters: accuracyMeters ?? 0,
      status: status,
      verifiedOfficeLocationId: verifiedOfficeLocationId,
      verifiedOfficeName: verifiedOfficeName,
      nearestOfficeLocationId: nearestOfficeLocationId,
      nearestOfficeName: nearestOfficeName,
      distanceMeters: distanceMeters,
      geofenceRadiusMeters: geofenceRadiusMeters,
    );
  }

  final ClockLocationStatus status = locationStatus == null
      ? ((isInsideGeofence ?? false)
            ? ClockLocationStatus.insideOffice
            : ClockLocationStatus.outsideAllOffices)
      : ClockLocationStatusLabels.fromDbValue(locationStatus);

  return ClockLocationSnapshot(
    coordinates:
        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
    accuracyMeters: accuracyMeters ?? 0,
    status: status,
    verifiedOfficeLocationId: verifiedOfficeLocationId,
    verifiedOfficeName: verifiedOfficeName,
    nearestOfficeLocationId: nearestOfficeLocationId,
    nearestOfficeName: nearestOfficeName,
    distanceMeters: distanceMeters,
    geofenceRadiusMeters: geofenceRadiusMeters,
  );
}
