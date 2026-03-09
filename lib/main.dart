import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/home_screen.dart';
import 'package:pulseclock/pulseclock/styles.dart';

void main() {
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
      home: const PulseClockHomeScreen(),
    );
  }
}
