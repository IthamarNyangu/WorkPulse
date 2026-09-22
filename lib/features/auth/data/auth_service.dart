import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/notifications/data/workpulse_push_service.dart';
import 'package:pulseclock/features/notifications/data/background_geofence_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  static const String profilesTableName = 'profiles';

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  bool get isSignedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> sendPasswordReset({required String email}) {
    return _client.auth.resetPasswordForEmail(email);
  }

  Future<WorkPulseUserProfile?> fetchCurrentProfile() async {
    final User? user = currentUser;
    if (user == null) {
      return null;
    }

    final Map<String, dynamic>? row = await _client
        .from(profilesTableName)
        .select(
          'id, employee_id, full_name, email, role, department, department_id, '
          'job_title, usual_office_location_id, is_active',
        )
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    final List<String> roles = await _fetchCurrentProfileRoles(user.id, row);

    return WorkPulseUserProfile.fromMap(row, roles: roles);
  }

  Future<void> logout() async {
    await WorkPulsePushService.instance.deactivate();
    await BackgroundGeofenceService().clear();
    await _client.auth.signOut();
  }

  Future<List<String>> _fetchCurrentProfileRoles(
    String profileId,
    Map<String, dynamic> profileRow,
  ) async {
    try {
      final List<dynamic> rows = await _client
          .from('profile_roles')
          .select('role')
          .eq('profile_id', profileId);
      final Set<String> roles = rows
          .map((dynamic row) => (row as Map)['role'] as String?)
          .whereType<String>()
          .toSet();
      roles.add('employee');
      return _sortRoles(roles);
    } catch (_) {
      return _sortRoles(<String>{
        'employee',
        profileRow['role'] as String? ?? 'employee',
      });
    }
  }
}

class WorkPulseUserProfile {
  const WorkPulseUserProfile({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.roles,
    this.department,
    this.departmentId,
    this.jobTitle,
    this.usualOfficeLocationId,
    this.isActive = true,
  });

  final String id;
  final String employeeId;
  final String fullName;
  final String email;
  final String role;
  final List<String> roles;
  final String? department;
  final String? departmentId;
  final String? jobTitle;
  final String? usualOfficeLocationId;
  final bool isActive;

  String get firstName {
    final List<String> parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return fullName;
    }
    return parts.first;
  }

  bool hasRole(String role) => roles.contains(role);

  bool hasAnyRole(Set<String> roleSet) => roles.any(roleSet.contains);

  String get effectiveRole {
    if (roles.contains('admin')) {
      return 'admin';
    }
    if (roles.contains('hr')) {
      return 'hr';
    }
    if (roles.contains('supervisor')) {
      return 'supervisor';
    }
    return 'employee';
  }

  factory WorkPulseUserProfile.fromMap(
    Map<String, dynamic> map, {
    List<String>? roles,
  }) {
    final List<String> resolvedRoles =
        roles ??
        _sortRoles(<String>{'employee', map['role'] as String? ?? 'employee'});
    return WorkPulseUserProfile(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      roles: resolvedRoles,
      department: map['department'] as String?,
      departmentId: map['department_id'] as String?,
      jobTitle: map['job_title'] as String?,
      usualOfficeLocationId: map['usual_office_location_id'] as String?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

List<String> _sortRoles(Iterable<String> roles) {
  const List<String> order = <String>['employee', 'supervisor', 'hr', 'admin'];
  final Set<String> normalized = roles
      .where((String role) => order.contains(role))
      .toSet();
  if (normalized.isEmpty) {
    normalized.add('employee');
  }
  return order.where(normalized.contains).toList(growable: false);
}
