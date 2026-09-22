import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/styles.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF111827), Color(0xFF5A1622)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 52,
                  ),
                  child: Column(
                    children: <Widget>[
                      const _WorkPulseBrand(),
                      const SizedBox(height: 24),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.42,
                        ),
                        child: Image.asset(
                          'assets/images/workpulse-login-illustration.png',
                          fit: BoxFit.contain,
                          semanticLabel:
                              'Employee using WorkPulse for attendance',
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Work made simpler',
                        textAlign: TextAlign.center,
                        style: PulseClockTextStyles.headerTitle.copyWith(
                          fontSize: 30,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Clock in securely with smart reminders, track your attendance, manage requests, and stay connected wherever work takes you.',
                        textAlign: TextAlign.center,
                        style: PulseClockTextStyles.headerSubtitle.copyWith(
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PulseClockColors.actionBlue,
                            foregroundColor: PulseClockColors.surface,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: PulseClockTextStyles.contextAction
                                .copyWith(
                                  color: PulseClockColors.surface,
                                  fontSize: 17,
                                ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your account is managed by your organisation.',
                        textAlign: TextAlign.center,
                        style: PulseClockTextStyles.headerSubtitle.copyWith(
                          fontSize: 12,
                          color: PulseClockColors.onBackgroundSecondary
                              .withValues(alpha: 0.84),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorkPulseBrand extends StatelessWidget {
  const _WorkPulseBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.asset(
            'assets/branding/workpulse_app_icon.png',
            width: 48,
            height: 48,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'WorkPulse',
          style: PulseClockTextStyles.headerTitle.copyWith(fontSize: 30),
        ),
      ],
    );
  }
}
