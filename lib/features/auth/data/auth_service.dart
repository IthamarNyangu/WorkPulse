import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
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

  Future<WorkPulseUserProfile?> fetchCurrentProfile() async {
    final User? user = currentUser;
    if (user == null) {
      return null;
    }

    final Map<String, dynamic>? row =
        (await _client
                .from(profilesTableName)
                .select('id, employee_id, full_name, email, role, department')
                .eq('id', user.id)
                .maybeSingle())
            as Map<String, dynamic>?;

    if (row == null) {
      return null;
    }

    return WorkPulseUserProfile.fromMap(row);
  }

  Future<void> logout() {
    return _client.auth.signOut();
  }
}

class WorkPulseUserProfile {
  const WorkPulseUserProfile({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.email,
    required this.role,
    this.department,
  });

  final String id;
  final String employeeId;
  final String fullName;
  final String email;
  final String role;
  final String? department;

  String get firstName {
    final List<String> parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return fullName;
    }
    return parts.first;
  }

  factory WorkPulseUserProfile.fromMap(Map<String, dynamic> map) {
    return WorkPulseUserProfile(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      department: map['department'] as String?,
    );
  }
}
