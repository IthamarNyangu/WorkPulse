import 'package:flutter/material.dart';
import 'package:pulseclock/features/attendance/home/pulse_clock_home_screen.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/features/auth/presentation/login_screen.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthGate extends StatelessWidget {
  const SupabaseAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (BuildContext context, AsyncSnapshot<AuthState> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !authService.isSignedIn) {
          return const _AuthLoadingScreen();
        }

        final User? currentUser = authService.currentUser;
        if (currentUser != null) {
          return FutureBuilder<WorkPulseUserProfile?>(
            future: authService.fetchCurrentProfile(),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<WorkPulseUserProfile?> profileSnapshot,
                ) {
                  if (profileSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const _AuthLoadingScreen();
                  }
                  final WorkPulseUserProfile? profile = profileSnapshot.data;
                  if (profile != null && !profile.isActive) {
                    return _InactiveAccountScreen(authService: authService);
                  }
                  return PulseClockHomeScreen(
                    key: ValueKey<String>(currentUser.id),
                  );
                },
          );
        }

        return const LoginScreen();
      },
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
