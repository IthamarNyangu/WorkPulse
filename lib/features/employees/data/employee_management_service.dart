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

class WorkPulseJobTitle {
  const WorkPulseJobTitle({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String name;
  final bool isActive;

  factory WorkPulseJobTitle.fromMap(Map<String, dynamic> map) {
    return WorkPulseJobTitle(
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
    required this.roles,
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
  final List<String> roles;
  final bool isActive;
  final String? departmentId;
  final String? departmentName;
  final String? jobTitle;
  final String? usualOfficeLocationId;
  final String? usualOfficeName;
  final String? supervisorId;
  final String? supervisorName;

  String get roleLabel {
    if (roles.length > 1) {
      return roles.map(_roleLabel).join(', ');
    }
    return _roleLabel(role);
  }

  bool hasRole(String role) => roles.contains(role);

  static String _roleLabel(String role) {
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
    required Map<String, List<String>> rolesByProfile,
  }) {
    final String? departmentId = map['department_id'] as String?;
    final String? officeId = map['usual_office_location_id'] as String?;
    final String id = map['id'] as String;
    final String primaryRole = map['role'] as String? ?? 'employee';
    final String? supervisorId = supervisorIdsByEmployee[id];
    return ManagedEmployeeProfile(
      id: id,
      employeeId: map['employee_id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      role: primaryRole,
      roles:
          rolesByProfile[id] ?? _sortedRoles(<String>{'employee', primaryRole}),
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
    required this.jobTitles,
    required this.offices,
    required this.supervisors,
  });

  final List<ManagedEmployeeProfile> employees;
  final List<WorkPulseDepartment> departments;
  final List<WorkPulseJobTitle> jobTitles;
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

  Future<String> createEmployee({
    required String email,
    required String temporaryPassword,
    required String employeeId,
    required String fullName,
    required String? jobTitle,
    required String? departmentId,
    required String? usualOfficeLocationId,
    required String? supervisorId,
    required List<String> roles,
    required bool isActive,
  }) async {
    final FunctionResponse response = await _client.functions.invoke(
      'create-workpulse-employee',
      body: <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'password': temporaryPassword,
        'employeeId': employeeId.trim(),
        'fullName': fullName.trim(),
        'jobTitle': _blankToNull(jobTitle),
        'departmentId': departmentId,
        'usualOfficeLocationId': usualOfficeLocationId,
        'supervisorId': supervisorId,
        'roles': _sortedRoles(<String>{'employee', ...roles}),
        'isActive': isActive,
      },
    );
    final dynamic responseData = response.data;
    final Map<String, dynamic> data = responseData is Map
        ? Map<String, dynamic>.from(responseData)
        : <String, dynamic>{};
    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        data['error'] as String? ?? 'Unable to create the employee account.',
      );
    }
    final String? profileId = data['id'] as String?;
    if (profileId == null || profileId.isEmpty) {
      throw StateError(
        'The employee account was created without a profile ID.',
      );
    }
    return profileId;
  }

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

  Future<List<WorkPulseJobTitle>> fetchJobTitles() async {
    final List<dynamic> rows = await _client
        .from('job_titles')
        .select('id, name, is_active')
        .order('is_active', ascending: false)
        .order('name', ascending: true);
    return rows
        .map(
          (dynamic row) => WorkPulseJobTitle.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<EmployeeManagementData> fetchManagementData({
    required String currentUserId,
    required List<String> currentRoles,
  }) async {
    final List<WorkPulseDepartment> departments = await fetchDepartments();
    final List<WorkPulseJobTitle> jobTitles = await fetchJobTitles();

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
    final Map<String, List<String>> rolesByProfile = await _fetchRolesByProfile(
      profileMaps,
    );

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
            rolesByProfile: rolesByProfile,
          ),
        )
        .toList(growable: false);
    final bool isOrganisationManager =
        currentRoles.contains('hr') || currentRoles.contains('admin');
    final bool isSupervisorOnly =
        currentRoles.contains('supervisor') && !isOrganisationManager;
    final List<ManagedEmployeeProfile> employees = isSupervisorOnly
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
              employee.hasRole('supervisor') && employee.isActive,
        )
        .toList(growable: false);

    return EmployeeManagementData(
      employees: employees,
      departments: departments,
      jobTitles: jobTitles,
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
    required List<String> roles,
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
        'p_roles': _sortedRoles(<String>{'employee', ...roles}),
        'p_is_active': isActive,
      },
    );
  }

  Future<Map<String, List<String>>> _fetchRolesByProfile(
    List<Map<String, dynamic>> profileMaps,
  ) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'list_visible_profile_roles',
      );
      final Map<String, Set<String>> grouped = <String, Set<String>>{};
      for (final dynamic rawRow in rows) {
        final Map<String, dynamic> row = Map<String, dynamic>.from(
          rawRow as Map,
        );
        final String? profileId = row['profile_id'] as String?;
        final String? role = row['role'] as String?;
        if (profileId == null || role == null) {
          continue;
        }
        grouped.putIfAbsent(profileId, () => <String>{'employee'}).add(role);
      }
      return <String, List<String>>{
        for (final MapEntry<String, Set<String>> entry in grouped.entries)
          entry.key: _sortedRoles(entry.value),
      };
    } catch (_) {
      return <String, List<String>>{
        for (final Map<String, dynamic> profile in profileMaps)
          profile['id'] as String: _sortedRoles(<String>{
            'employee',
            profile['role'] as String? ?? 'employee',
          }),
      };
    }
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

  Future<WorkPulseJobTitle> createJobTitle(String name) async {
    final Map<String, dynamic> row = await _client
        .from('job_titles')
        .insert(<String, dynamic>{
          'name': name.trim(),
          'created_by': _client.auth.currentUser?.id,
        })
        .select('id, name, is_active')
        .single();
    return WorkPulseJobTitle.fromMap(row);
  }

  Future<WorkPulseJobTitle> updateJobTitle({
    required WorkPulseJobTitle jobTitle,
    required String name,
    required bool isActive,
  }) async {
    final Map<String, dynamic> row = await _client
        .from('job_titles')
        .update(<String, dynamic>{'name': name.trim(), 'is_active': isActive})
        .eq('id', jobTitle.id)
        .select('id, name, is_active')
        .single();
    return WorkPulseJobTitle.fromMap(row);
  }

  String? _blankToNull(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

List<String> _sortedRoles(Iterable<String> roles) {
  const List<String> order = <String>['employee', 'supervisor', 'hr', 'admin'];
  final Set<String> normalized = roles
      .where((String role) => order.contains(role))
      .toSet();
  if (normalized.isEmpty) {
    normalized.add('employee');
  }
  return order.where(normalized.contains).toList(growable: false);
}
