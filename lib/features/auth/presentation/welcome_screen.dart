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
              final bool compactHeight = constraints.maxHeight < 720;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  28,
                  compactHeight ? 24 : 40,
                  28,
                  18,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - (compactHeight ? 42 : 58),
                  ),
                  child: Column(
                    children: <Widget>[
                      const _WorkPulseBrand(),
                      SizedBox(height: compactHeight ? 12 : 18),
                      Transform.translate(
                        offset: const Offset(0, 5),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                constraints.maxHeight *
                                (compactHeight ? 0.39 : 0.46),
                          ),
                          child: Image.asset(
                            'assets/images/workpulse-login-illustration.png',
                            fit: BoxFit.contain,
                            semanticLabel:
                                'Employee using WorkPulse for attendance',
                          ),
                        ),
                      ),
                      SizedBox(height: compactHeight ? 8 : 12),
                      Text(
                        'Your workday, in sync.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                          letterSpacing: -0.7,
                          color: PulseClockColors.surface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 355),
                        child: const Text(
                          'Clock in, track attendance, and manage requests wherever you work.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.45,
                            color: Color(0xFFD5D9E2),
                          ),
                        ),
                      ),
                      SizedBox(height: compactHeight ? 16 : 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: onSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PulseClockColors.actionBlue,
                            foregroundColor: PulseClockColors.surface,
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your account is managed by your organisation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                          color: Color(0xFFBFC5D0),
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
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset(
              'assets/branding/workpulse_app_icon.png',
              width: 42,
              height: 42,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'WorkPulse',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.35,
              color: PulseClockColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}
