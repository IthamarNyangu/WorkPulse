import 'package:flutter/material.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/auth/presentation/supabase_auth_gate.dart';
import 'package:pulseclock/features/notifications/data/local_notification_service.dart';
import 'package:pulseclock/features/notifications/data/workpulse_push_service.dart';
import 'package:pulseclock/pulseclock/home_screen.dart';
import 'package:pulseclock/pulseclock/styles.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize();
  await WorkPulseLocalNotificationService.instance.initialize();
  await WorkPulsePushService.instance.initialize();
  runApp(const PulseClockApp());
}

class PulseClockApp extends StatelessWidget {
  const PulseClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: PulseClockColors.appBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: PulseClockColors.appBackgroundSolid,
          brightness: Brightness.light,
        ),
      ),
      home: SupabaseBootstrap.isInitialized
          ? const SupabaseAuthGate()
          : const PulseClockHomeScreen(),
    );
  }
}
