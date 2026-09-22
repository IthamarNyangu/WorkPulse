import 'package:flutter/material.dart';
import 'package:pulseclock/features/attendance/home/pulse_clock_home_screen.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/features/auth/presentation/login_screen.dart';
import 'package:pulseclock/features/auth/presentation/welcome_screen.dart';
import 'package:pulseclock/features/auth/session/workpulse_session.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthGate extends StatefulWidget {
  const SupabaseAuthGate({super.key});

  @override
  State<SupabaseAuthGate> createState() => _SupabaseAuthGateState();
}

class _SupabaseAuthGateState extends State<SupabaseAuthGate> {
  late final AuthService _authService;
  String? _profileUserId;
  Future<WorkPulseUserProfile?>? _profileFuture;
  WorkPulseSessionController? _sessionController;
  bool _showSignIn = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  @override
  void dispose() {
    _sessionController?.dispose();
    super.dispose();
  }

  Future<WorkPulseUserProfile?> _profileFor(User user) {
    if (_profileUserId != user.id || _profileFuture == null) {
      _disposeSessionAfterFrame();
      _sessionController = null;
      _profileUserId = user.id;
      _profileFuture = _authService.fetchCurrentProfile();
    }
    return _profileFuture!;
  }

  void _retryProfile() {
    setState(() {
      _disposeSessionAfterFrame();
      _sessionController = null;
      _profileFuture = null;
    });
  }

  void _disposeSessionAfterFrame() {
    final WorkPulseSessionController? previousController = _sessionController;
    if (previousController == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previousController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (BuildContext context, AsyncSnapshot<AuthState> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_authService.isSignedIn) {
          return const _AuthLoadingScreen();
        }

        final User? currentUser = _authService.currentUser;
        if (currentUser != null) {
          return FutureBuilder<WorkPulseUserProfile?>(
            future: _profileFor(currentUser),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<WorkPulseUserProfile?> profileSnapshot,
                ) {
                  if (profileSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const _AuthLoadingScreen();
                  }
                  if (profileSnapshot.hasError ||
                      profileSnapshot.data == null) {
                    return _ProfileLoadErrorScreen(onRetry: _retryProfile);
                  }
                  final WorkPulseUserProfile? profile = profileSnapshot.data;
                  if (profile != null && !profile.isActive) {
                    return _InactiveAccountScreen(authService: _authService);
                  }
                  _sessionController ??= WorkPulseSessionController(
                    profile: profile!,
                    authService: _authService,
                  );
                  return WorkPulseSessionScope(
                    controller: _sessionController!,
                    child: PulseClockHomeScreen(
                      key: ValueKey<String>(currentUser.id),
                    ),
                  );
                },
          );
        }

        if (!_showSignIn) {
          return WelcomeScreen(
            onSignIn: () => setState(() => _showSignIn = true),
          );
        }
        return LoginScreen(onBack: () => setState(() => _showSignIn = false));
      },
    );
  }
}

class _ProfileLoadErrorScreen extends StatelessWidget {
  const _ProfileLoadErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: PulseClockColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 42,
                    color: PulseClockColors.statusPendingAccent,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Unable to Load Account',
                    style: PulseClockTextStyles.cardTitle.copyWith(
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'WorkPulse could not load your account permissions. Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: PulseClockTextStyles.cardSubtitle,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PulseClockColors.actionBlue,
                        foregroundColor: PulseClockColors.surface,
                      ),
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InactiveAccountScreen extends StatelessWidget {
  const _InactiveAccountScreen({required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: PulseClockColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_off_outlined,
                    size: 42,
                    color: PulseClockColors.statusMissedAccent,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Account Inactive',
                    style: PulseClockTextStyles.cardTitle.copyWith(
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your WorkPulse account is currently inactive. Contact HR or an administrator for assistance.',
                    textAlign: TextAlign.center,
                    style: PulseClockTextStyles.cardSubtitle,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: authService.logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PulseClockColors.actionBlue,
                        foregroundColor: PulseClockColors.surface,
                      ),
                      child: const Text('Return to Sign In'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(PulseClockColors.surface),
        ),
      ),
    );
  }
}
