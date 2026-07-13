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
          return PulseClockHomeScreen(key: ValueKey<String>(currentUser.id));
        }

        return const LoginScreen();
      },
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
