import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/location/office_location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkPulseDepartment {
  const WorkPulseDepartment({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String name;
  final bool isActive;

  factory WorkPulseDepartment.fromMap(Map<String, dynamic> map) {
    return WorkPulseDepartment(
      id: map['id'] as String,
      name: map['name'] as String,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class ManagedEmployeeProfile {
  const ManagedEmployeeProfile({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    this.departmentId,
    this.departmentName,
    this.jobTitle,
    this.usualOfficeLocationId,
    this.usualOfficeName,
    this.supervisorId,
    this.supervisorName,
  });

  final String id;
  final String employeeId;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final String? departmentId;
  final String? departmentName;
  final String? jobTitle;
  final String? usualOfficeLocationId;
  final String? usualOfficeName;
  final String? supervisorId;
  final String? supervisorName;

  String get roleLabel {
    switch (role) {
      case 'supervisor':
        return 'Supervisor';
      case 'hr':
        return 'HR';
      case 'admin':
        return 'Administrator';
      default:
        return 'Employee';
    }
  }

  factory ManagedEmployeeProfile.fromMap(
    Map<String, dynamic> map, {
    required Map<String, String> departmentNames,
    required Map<String, String> officeNames,
    required Map<String, String> supervisorIdsByEmployee,
    required Map<String, String> profileNames,
  }) {
    final String? departmentId = map['department_id'] as String?;
    final String? officeId = map['usual_office_location_id'] as String?;
    final String id = map['id'] as String;
    final String? supervisorId = supervisorIdsByEmployee[id];
    return ManagedEmployeeProfile(
      id: id,
      employeeId: map['employee_id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      role: map['role'] as String? ?? 'employee',
      isActive: map['is_active'] as bool? ?? true,
      departmentId: departmentId,
      departmentName:
          departmentNames[departmentId] ?? map['department'] as String?,
      jobTitle: map['job_title'] as String?,
      usualOfficeLocationId: officeId,
      usualOfficeName: officeNames[officeId],
      supervisorId: supervisorId,
      supervisorName: profileNames[supervisorId],
    );
  }
}

class EmployeeManagementData {
  const EmployeeManagementData({
    required this.employees,
    required this.departments,
    required this.offices,
    required this.supervisors,
  });

  final List<ManagedEmployeeProfile> employees;
  final List<WorkPulseDepartment> departments;
  final List<OfficeLocation> offices;
  final List<ManagedEmployeeProfile> supervisors;
}

class EmployeeManagementService {
  EmployeeManagementService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  static const String _profileColumns =
      'id, employee_id, full_name, email, role, department, department_id, '
      'job_title, usual_office_location_id, is_active';

  final SupabaseClient _client;

  Future<List<WorkPulseDepartment>> fetchDepartments() async {
    final List<dynamic> rows = await _client
        .from('departments')
        .select('id, name, is_active')
        .order('is_active', ascending: false)
        .order('name', ascending: true);
    return rows
        .map(
          (dynamic row) => WorkPulseDepartment.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<EmployeeManagementData> fetchManagementData({
    required String currentUserId,
    required String currentRole,
  }) async {
    final List<WorkPulseDepartment> departments = await fetchDepartments();

    final List<OfficeLocation> offices = await OfficeLocationService(
      client: _client,
    ).fetchOfficeLocations();

    final Map<String, String> departmentNames = <String, String>{
      for (final WorkPulseDepartment department in departments)
        department.id: department.name,
    };
    final Map<String, String> officeNames = <String, String>{
      for (final OfficeLocation office in offices) office.id: office.officeName,
    };

    final List<dynamic> profileRows = await _client
        .from('profiles')
        .select(_profileColumns)
        .order('is_active', ascending: false)
        .order('full_name', ascending: true);
    final List<Map<String, dynamic>> profileMaps = profileRows
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final Map<String, String> profileNames = <String, String>{
      for (final Map<String, dynamic> profile in profileMaps)
        profile['id'] as String: profile['full_name'] as String,
    };

    final List<dynamic> assignmentRows = await _client
        .from('employee_supervisor_assignments')
        .select('employee_id, supervisor_id')
        .eq('is_active', true)
        .eq('is_primary', true);
    final Map<String, String> supervisorIdsByEmployee = <String, String>{
      for (final dynamic rawRow in assignmentRows)
        (rawRow as Map)['employee_id'] as String:
            rawRow['supervisor_id'] as String,
    };

    final List<ManagedEmployeeProfile> visibleEmployees = profileMaps
        .map(
          (Map<String, dynamic> row) => ManagedEmployeeProfile.fromMap(
            row,
            departmentNames: departmentNames,
            officeNames: officeNames,
            supervisorIdsByEmployee: supervisorIdsByEmployee,
            profileNames: profileNames,
          ),
        )
        .toList(growable: false);
    final List<ManagedEmployeeProfile> employees = currentRole == 'supervisor'
        ? visibleEmployees
              .where(
                (ManagedEmployeeProfile employee) =>
                    employee.id != currentUserId,
              )
              .toList(growable: false)
        : visibleEmployees;
    final List<ManagedEmployeeProfile> supervisors = visibleEmployees
        .where(
          (ManagedEmployeeProfile employee) =>
              employee.role == 'supervisor' && employee.isActive,
        )
        .toList(growable: false);

    return EmployeeManagementData(
      employees: employees,
      departments: departments,
      offices: offices,
      supervisors: supervisors,
    );
  }

  Future<void> updateEmployee({
    required ManagedEmployeeProfile employee,
    required String employeeId,
    required String fullName,
    required String? jobTitle,
    required String? departmentId,
    required String? usualOfficeLocationId,
    required String? supervisorId,
    required String role,
    required bool isActive,
  }) {
    return _client.rpc<void>(
      'update_employee_profile',
      params: <String, dynamic>{
        'p_profile_id': employee.id,
        'p_employee_id': employeeId.trim(),
        'p_full_name': fullName.trim(),
        'p_job_title': _blankToNull(jobTitle),
        'p_department_id': departmentId,
        'p_usual_office_location_id': usualOfficeLocationId,
        'p_supervisor_id': supervisorId,
        'p_role': role,
        'p_is_active': isActive,
      },
    );
  }

  Future<WorkPulseDepartment> createDepartment(String name) async {
    final Map<String, dynamic> row = await _client
        .from('departments')
        .insert(<String, dynamic>{
          'name': name.trim(),
          'created_by': _client.auth.currentUser?.id,
        })
        .select('id, name, is_active')
        .single();
    return WorkPulseDepartment.fromMap(row);
  }

  Future<WorkPulseDepartment> updateDepartment({
    required WorkPulseDepartment department,
    required String name,
    required bool isActive,
  }) async {
    final Map<String, dynamic> row = await _client
        .from('departments')
        .update(<String, dynamic>{'name': name.trim(), 'is_active': isActive})
        .eq('id', department.id)
        .select('id, name, is_active')
        .single();
    return WorkPulseDepartment.fromMap(row);
  }

  String? _blankToNull(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
