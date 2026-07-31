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
  }) {
    final String? departmentId = map['department_id'] as String?;
    final String? officeId = map['usual_office_location_id'] as String?;
    return ManagedEmployeeProfile(
      id: map['id'] as String,
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
    );
  }
}

class EmployeeManagementData {
  const EmployeeManagementData({
    required this.employees,
    required this.departments,
    required this.offices,
  });

  final List<ManagedEmployeeProfile> employees;
  final List<WorkPulseDepartment> departments;
  final List<OfficeLocation> offices;
}

class EmployeeManagementService {
  EmployeeManagementService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  static const String _profileColumns =
      'id, employee_id, full_name, email, role, department, department_id, '
      'job_title, usual_office_location_id, is_active';

  final SupabaseClient _client;

  Future<EmployeeManagementData> fetchManagementData() async {
    final List<dynamic> departmentRows = await _client
        .from('departments')
        .select('id, name, is_active')
        .order('is_active', ascending: false)
        .order('name', ascending: true);
    final List<WorkPulseDepartment> departments = departmentRows
        .map(
          (dynamic row) => WorkPulseDepartment.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);

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
    final List<ManagedEmployeeProfile> employees = profileRows
        .map(
          (dynamic row) => ManagedEmployeeProfile.fromMap(
            Map<String, dynamic>.from(row as Map),
            departmentNames: departmentNames,
            officeNames: officeNames,
          ),
        )
        .toList(growable: false);

    return EmployeeManagementData(
      employees: employees,
      departments: departments,
      offices: offices,
    );
  }

  Future<void> updateEmployee({
    required ManagedEmployeeProfile employee,
    required String employeeId,
    required String fullName,
    required String? jobTitle,
    required String? departmentId,
    required String? usualOfficeLocationId,
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
