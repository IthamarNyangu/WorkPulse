import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/location/office_location_service.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum GeofenceExceptionAction { clockIn, clockOut }

extension GeofenceExceptionActionLabels on GeofenceExceptionAction {
  String get label {
    switch (this) {
      case GeofenceExceptionAction.clockIn:
        return 'Clock In';
      case GeofenceExceptionAction.clockOut:
        return 'Clock Out';
    }
  }
}

class GeofenceExceptionItem {
  const GeofenceExceptionItem({
    required this.id,
    required this.attendanceRecordId,
    required this.employeeName,
    required this.employeeId,
    required this.workDate,
    required this.action,
    required this.status,
    this.actionTime,
    this.coordinates,
    this.accuracyMeters,
    this.verifiedOfficeName,
    this.nearestOfficeName,
    this.distanceMeters,
    this.geofenceRadiusMeters,
    this.comment,
    this.attendanceStatus,
  });

  final String id;
  final String attendanceRecordId;
  final String employeeName;
  final String employeeId;
  final DateTime workDate;
  final DateTime? actionTime;
  final GeofenceExceptionAction action;
  final ClockLocationStatus status;
  final String? coordinates;
  final double? accuracyMeters;
  final String? verifiedOfficeName;
  final String? nearestOfficeName;
  final double? distanceMeters;
  final double? geofenceRadiusMeters;
  final String? comment;
  final String? attendanceStatus;

  String get dateLabelText => dateLabel(workDate);
  String get actionTimeLabel =>
      actionTime == null ? '--' : timeLabel(actionTime!);
  String? get officeDisplayName => verifiedOfficeName ?? nearestOfficeName;
}

class GeofenceExceptionService {
  GeofenceExceptionService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client,
      _authService = AuthService(client: client ?? SupabaseBootstrap.client),
      _officeLocationService = OfficeLocationService(
        client: client ?? SupabaseBootstrap.client,
      );

  static const String attendanceTableName = 'attendance_records';
  static const String profilesTableName = 'profiles';
  static const Set<String> reviewerRoles = <String>{'hr', 'admin'};

  final SupabaseClient _client;
  final AuthService _authService;
  final OfficeLocationService _officeLocationService;

  Future<List<GeofenceExceptionItem>> fetchExceptions({
    int lookbackDays = 90,
  }) async {
    final WorkPulseUserProfile profile = await _requireReviewerProfile();
    if (!profile.hasAnyRole(reviewerRoles)) {
      throw StateError(
        'Only HR and administrators can review geofence exceptions.',
      );
    }

    final DateTime today = DateTime.now();
    final DateTime startDate = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: lookbackDays));

    final List<dynamic> rows = await _client
        .from(attendanceTableName)
        .select()
        .gte('work_date', _dateOnlyLabel(startDate))
        .order('work_date', ascending: false)
        .order('updated_at', ascending: false);

    final List<Map<String, dynamic>> attendanceRows = rows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);

    final Map<String, _EmployeeSummary> employeesById = await _employeesForRows(
      attendanceRows,
    );
    final Map<String, String> officeNamesById = await _officeNamesById();
    final List<GeofenceExceptionItem> exceptions = <GeofenceExceptionItem>[];

    for (final Map<String, dynamic> row in attendanceRows) {
      exceptions.addAll(
        _exceptionsFromRow(
          row,
          employeesById: employeesById,
          officeNamesById: officeNamesById,
        ),
      );
    }

    exceptions.sort((GeofenceExceptionItem a, GeofenceExceptionItem b) {
      final DateTime aTime = a.actionTime ?? a.workDate;
      final DateTime bTime = b.actionTime ?? b.workDate;
      return bTime.compareTo(aTime);
    });

    return exceptions;
  }

  Future<WorkPulseUserProfile> _requireReviewerProfile() async {
    final WorkPulseUserProfile? profile = await _authService
        .fetchCurrentProfile();
    if (profile == null) {
      throw StateError('No active WorkPulse profile found.');
    }
    return profile;
  }

  Future<Map<String, _EmployeeSummary>> _employeesForRows(
    List<Map<String, dynamic>> rows,
  ) async {
    final Set<String> ids = rows
        .map((Map<String, dynamic> row) => row['user_id'] as String?)
        .whereType<String>()
        .toSet();
    if (ids.isEmpty) {
      return const <String, _EmployeeSummary>{};
    }

    final List<dynamic> profileRows = await _client
        .from(profilesTableName)
        .select('id, employee_id, full_name, email')
        .inFilter('id', ids.toList(growable: false));

    return <String, _EmployeeSummary>{
      for (final dynamic rawRow in profileRows)
        (rawRow as Map)['id'] as String: _EmployeeSummary.fromMap(
          Map<String, dynamic>.from(rawRow),
        ),
    };
  }

  Future<Map<String, String>> _officeNamesById() async {
    final List<OfficeLocation> offices = await _officeLocationService
        .fetchOfficeLocations();
    return <String, String>{
      for (final OfficeLocation office in offices) office.id: office.officeName,
    };
  }

  List<GeofenceExceptionItem> _exceptionsFromRow(
    Map<String, dynamic> row, {
    required Map<String, _EmployeeSummary> employeesById,
    required Map<String, String> officeNamesById,
  }) {
    final List<GeofenceExceptionItem> exceptions = <GeofenceExceptionItem>[];
    final String attendanceRecordId = row['id'] as String;
    final String userId = row['user_id'] as String;
    final _EmployeeSummary? employee = employeesById[userId];
    final String employeeId =
        employee?.employeeId ?? row['employee_id'] as String? ?? 'Unknown';
    final String employeeName = employee?.fullName ?? employeeId;
    final DateTime workDate = DateTime.parse(row['work_date'] as String);

    final GeofenceExceptionItem? clockInException = _exceptionForAction(
      row: row,
      attendanceRecordId: attendanceRecordId,
      employeeName: employeeName,
      employeeId: employeeId,
      workDate: workDate,
      action: GeofenceExceptionAction.clockIn,
      prefix: 'clock_in',
      officeNamesById: officeNamesById,
    );
    if (clockInException != null) {
      exceptions.add(clockInException);
    }

    final GeofenceExceptionItem? clockOutException = _exceptionForAction(
      row: row,
      attendanceRecordId: attendanceRecordId,
      employeeName: employeeName,
      employeeId: employeeId,
      workDate: workDate,
      action: GeofenceExceptionAction.clockOut,
      prefix: 'clock_out',
      officeNamesById: officeNamesById,
    );
    if (clockOutException != null) {
      exceptions.add(clockOutException);
    }

    return exceptions;
  }

  GeofenceExceptionItem? _exceptionForAction({
    required Map<String, dynamic> row,
    required String attendanceRecordId,
    required String employeeName,
    required String employeeId,
    required DateTime workDate,
    required GeofenceExceptionAction action,
    required String prefix,
    required Map<String, String> officeNamesById,
  }) {
    final DateTime? actionTime = _parseDateTime(row[prefix]);
    if (actionTime == null) {
      return null;
    }

    final String? statusValue = row['${prefix}_location_status'] as String?;
    if (statusValue == null || statusValue == 'inside_office') {
      return null;
    }

    final ClockLocationStatus status = ClockLocationStatusLabels.fromDbValue(
      statusValue,
    );
    final String? verifiedOfficeLocationId =
        row['${prefix}_verified_office_location_id'] as String?;
    final String? nearestOfficeLocationId =
        row['${prefix}_nearest_office_location_id'] as String?;
    final double? latitude = _parseDouble(row['${prefix}_lat']);
    final double? longitude = _parseDouble(row['${prefix}_lng']);

    return GeofenceExceptionItem(
      id: '$attendanceRecordId-${action.name}',
      attendanceRecordId: attendanceRecordId,
      employeeName: employeeName,
      employeeId: employeeId,
      workDate: workDate,
      actionTime: actionTime,
      action: action,
      status: status,
      coordinates: latitude == null || longitude == null
          ? null
          : '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
      accuracyMeters: _parseDouble(row['${prefix}_accuracy_m']),
      verifiedOfficeName: officeNamesById[verifiedOfficeLocationId],
      nearestOfficeName: officeNamesById[nearestOfficeLocationId],
      distanceMeters: _parseDouble(row['${prefix}_distance_m']),
      geofenceRadiusMeters: _parseDouble(row['${prefix}_geofence_radius_m']),
      comment: row['${prefix}_comment'] as String?,
      attendanceStatus: row['status'] as String?,
    );
  }

  DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String).toLocal();
  }

  double? _parseDouble(Object? value) {
    if (value == null) {
      return null;
    }
    return (value as num).toDouble();
  }

  String _dateOnlyLabel(DateTime dateTime) {
    final String year = dateTime.year.toString().padLeft(4, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _EmployeeSummary {
  const _EmployeeSummary({required this.employeeId, required this.fullName});

  final String employeeId;
  final String fullName;

  factory _EmployeeSummary.fromMap(Map<String, dynamic> map) {
    return _EmployeeSummary(
      employeeId: map['employee_id'] as String,
      fullName: map['full_name'] as String,
    );
  }
}
