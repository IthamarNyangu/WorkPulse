import 'package:flutter/material.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your email and password.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _authService.login(email: email, password: password);
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _friendlyAuthError(error.message);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage =
            'Unable to sign in right now. Check your internet connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111827), Color(0x995A1622)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  PulseClockDimensions.horizontalPadding,
                  28,
                  PulseClockDimensions.horizontalPadding,
                  28 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WorkPulse',
                        style: PulseClockTextStyles.headerTitle.copyWith(
                          fontSize: 34,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sign in to connect attendance to your Supabase account.',
                        style: PulseClockTextStyles.headerSubtitle,
                      ),
                      const SizedBox(height: 28),
                      SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Login',
                              style: PulseClockTextStyles.cardTitle.copyWith(
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use an email and password from Supabase Authentication.',
                              style: PulseClockTextStyles.cardSubtitle,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const <String>[
                                AutofillHints.username,
                              ],
                              enabled: !_isSubmitting,
                              decoration: _inputDecoration('Email'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
                              enabled: !_isSubmitting,
                              decoration: _inputDecoration('Password'),
                            ),
                            if (_errorMessage != null) ...<Widget>[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                style: PulseClockTextStyles.cardSubtitle
                                    .copyWith(
                                      color: const Color(0xFFB42318),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PulseClockColors.actionBlue,
                                  foregroundColor: PulseClockColors.surface,
                                  disabledBackgroundColor: PulseClockColors
                                      .actionBlue
                                      .withOpacity(0.55),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  textStyle: PulseClockTextStyles.contextAction
                                      .copyWith(
                                        color: PulseClockColors.surface,
                                        fontSize: 17,
                                      ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      PulseClockDimensions.cardRadius,
                                    ),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                PulseClockColors.surface,
                                              ),
                                        ),
                                      )
                                    : const Text('Sign In'),
                              ),
                            ),
                          ],
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: PulseClockColors.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PulseClockColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PulseClockColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: PulseClockColors.actionBlue,
          width: 1.4,
        ),
      ),
    );
  }

  String _friendlyAuthError(String message) {
    final String normalized = message.toLowerCase();

    if (normalized.contains('failed host lookup') ||
        normalized.contains('socketexception') ||
        normalized.contains('network') ||
        normalized.contains('connection')) {
      return 'WorkPulse could not reach Supabase. Check your internet connection, then try again.';
    }

    if (normalized.contains('invalid login credentials') ||
        normalized.contains('invalid email or password') ||
        normalized.contains('grant_type=password')) {
      return 'Incorrect email or password.';
    }

    if (normalized.contains('email not confirmed')) {
      return 'This account email is not confirmed yet.';
    }

    if (normalized.contains('too many requests')) {
      return 'Too many sign-in attempts. Please wait a moment and try again.';
    }

    return 'Unable to sign in right now. Please try again.';
  }
}
