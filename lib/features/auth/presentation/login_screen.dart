import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _rememberedEmailKey = 'workpulse_remembered_email';

  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _rememberEmail = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _restoreRememberedEmail();
  }

  Future<void> _restoreRememberedEmail() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String email = preferences.getString(_rememberedEmailKey) ?? '';
    if (!mounted || email.isEmpty) return;
    setState(() {
      _emailController.text = email;
      _rememberEmail = true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String email = _emailController.text.trim();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _authService.login(
        email: email,
        password: _passwordController.text,
      );
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      if (_rememberEmail) {
        await preferences.setString(_rememberedEmailKey, email);
      } else {
        await preferences.remove(_rememberedEmailKey);
      }
      TextInput.finishAutofillContext();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyAuthError(error.message));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to sign in right now. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showForgotPassword() async {
    final TextEditingController resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? dialogError;
    bool sending = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !sending,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            Future<void> sendReset() async {
              final String email = resetEmailController.text.trim();
              if (!_looksLikeEmail(email)) {
                setDialogState(
                  () => dialogError = 'Enter a valid work email address.',
                );
                return;
              }
              setDialogState(() {
                sending = true;
                dialogError = null;
              });
              try {
                await _authService.sendPasswordReset(email: email);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password reset instructions were sent to your work email.',
                    ),
                  ),
                );
              } on AuthException catch (error) {
                setDialogState(() {
                  dialogError = _friendlyResetError(error.message);
                  sending = false;
                });
              } catch (_) {
                setDialogState(() {
                  dialogError =
                      'Unable to send reset instructions right now. Try again.';
                  sending = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: PulseClockColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Reset password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Enter your work email and we’ll send password reset instructions.',
                    style: PulseClockTextStyles.cardSubtitle,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    enabled: !sending,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.email],
                    decoration: _inputDecoration(
                      label: 'Work email',
                      icon: Icons.mail_outline_rounded,
                    ),
                  ),
                  if (dialogError != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        color: const Color(0xFFB42318),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: sending ? null : sendReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PulseClockColors.actionBlue,
                    foregroundColor: PulseClockColors.surface,
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PulseClockColors.surface,
                          ),
                        )
                      : const Text('Send instructions'),
                ),
              ],
            );
          },
        );
      },
    );
    resetEmailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      resizeToAvoidBottomInset: true,
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      IconButton(
                        onPressed: _isSubmitting ? null : widget.onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: PulseClockColors.surface,
                        tooltip: 'Back',
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Column(
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                'assets/branding/workpulse_app_icon.png',
                                width: 56,
                                height: 56,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'WorkPulse',
                              style: PulseClockTextStyles.headerTitle.copyWith(
                                fontSize: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: PulseClockColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: PulseClockShadows.soft,
                        ),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Welcome back',
                                  style: PulseClockTextStyles.cardTitle
                                      .copyWith(fontSize: 28),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Sign in with your organisation account.',
                                  style: PulseClockTextStyles.cardSubtitle,
                                ),
                                const SizedBox(height: 22),
                                TextFormField(
                                  controller: _emailController,
                                  enabled: !_isSubmitting,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const <String>[
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  autocorrect: false,
                                  validator: (String? value) =>
                                      _looksLikeEmail(value?.trim() ?? '')
                                      ? null
                                      : 'Enter a valid work email address.',
                                  decoration: _inputDecoration(
                                    label: 'Work email',
                                    icon: Icons.mail_outline_rounded,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  enabled: !_isSubmitting,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const <String>[
                                    AutofillHints.password,
                                  ],
                                  validator: (String? value) =>
                                      value == null || value.isEmpty
                                      ? 'Enter your password.'
                                      : null,
                                  onFieldSubmitted: (_) => _login(),
                                  decoration:
                                      _inputDecoration(
                                        label: 'Password',
                                        icon: Icons.lock_outline_rounded,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                          tooltip: _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Checkbox(
                                      value: _rememberEmail,
                                      onChanged: _isSubmitting
                                          ? null
                                          : (bool? value) => setState(
                                              () => _rememberEmail =
                                                  value ?? false,
                                            ),
                                      activeColor: PulseClockColors.actionBlue,
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: _isSubmitting
                                            ? null
                                            : () => setState(
                                                () => _rememberEmail =
                                                    !_rememberEmail,
                                              ),
                                        child: Text(
                                          'Remember my email',
                                          style:
                                              PulseClockTextStyles.cardSubtitle,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : _showForgotPassword,
                                      child: const Text('Forgot password?'),
                                    ),
                                  ],
                                ),
                                if (_errorMessage != null) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFDF4F4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: PulseClockTextStyles.cardSubtitle
                                          .copyWith(
                                            color: const Color(0xFFB42318),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          PulseClockColors.actionBlue,
                                      foregroundColor: PulseClockColors.surface,
                                      disabledBackgroundColor: PulseClockColors
                                          .actionBlue
                                          .withValues(alpha: 0.55),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      textStyle: PulseClockTextStyles
                                          .contextAction
                                          .copyWith(
                                            color: PulseClockColors.surface,
                                            fontSize: 17,
                                          ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: PulseClockColors.surface,
                                            ),
                                          )
                                        : const Text('Sign In'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          'Need access? Contact your HR team.',
                          style: PulseClockTextStyles.headerSubtitle.copyWith(
                            fontSize: 13,
                          ),
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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: PulseClockColors.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
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

  bool _looksLikeEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  String _friendlyAuthError(String message) {
    final String normalized = message.toLowerCase();
    if (normalized.contains('network') ||
        normalized.contains('connection') ||
        normalized.contains('socketexception')) {
      return 'WorkPulse could not connect. Check your internet connection and try again.';
    }
    if (normalized.contains('invalid login credentials') ||
        normalized.contains('invalid email or password')) {
      return 'Incorrect email or password.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'This work email has not been confirmed. Contact HR for assistance.';
    }
    if (normalized.contains('too many requests')) {
      return 'Too many sign-in attempts. Wait a moment and try again.';
    }
    return 'Unable to sign in right now. Please try again.';
  }

  String _friendlyResetError(String message) {
    final String normalized = message.toLowerCase();
    if (normalized.contains('too many requests')) {
      return 'Too many reset attempts. Wait a moment and try again.';
    }
    if (normalized.contains('network') || normalized.contains('connection')) {
      return 'WorkPulse could not connect. Check your internet connection.';
    }
    return 'Unable to send reset instructions. Confirm the email and try again.';
  }
}
