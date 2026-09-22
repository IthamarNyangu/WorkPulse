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

class _LoginOptions extends StatelessWidget {
  const _LoginOptions({
    required this.compact,
    required this.rememberEmail,
    required this.enabled,
    required this.onRememberChanged,
    required this.onForgotPassword,
  });

  final bool compact;
  final bool rememberEmail;
  final bool enabled;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final Widget remember = InkWell(
      onTap: enabled ? () => onRememberChanged(!rememberEmail) : null,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 32,
            height: 36,
            child: Checkbox(
              value: rememberEmail,
              onChanged: enabled
                  ? (bool? value) => onRememberChanged(value ?? false)
                  : null,
              activeColor: PulseClockColors.actionBlue,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 3),
          const Expanded(
            child: Text(
              'Remember my email',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: PulseClockColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
    final Widget forgot = TextButton(
      onPressed: enabled ? onForgotPassword : null,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: const Text('Forgot password?'),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          remember,
          Align(alignment: Alignment.centerRight, child: forgot),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(child: remember),
        const SizedBox(width: 8),
        forgot,
      ],
    );
  }
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  static const String _rememberedEmailKey = 'workpulse_remembered_email';

  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _rememberEmail = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _keyboardWasVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _emailFocusNode.addListener(_handleFieldFocus);
    _passwordFocusNode.addListener(_handleFieldFocus);
    _restoreRememberedEmail();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final bool keyboardIsVisible = View.of(context).viewInsets.bottom > 0;
    if (keyboardIsVisible) {
      _keyboardWasVisible = true;
      return;
    }
    if (!_keyboardWasVisible) return;
    _keyboardWasVisible = false;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  void _handleFieldFocus() {
    if (mounted) setState(() {});
    if (!_emailFocusNode.hasFocus && !_passwordFocusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollFormForKeyboard(),
    );
    Future<void>.delayed(
      const Duration(milliseconds: 320),
      _scrollFormForKeyboard,
    );
  }

  void _scrollFormForKeyboard() {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
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
    WidgetsBinding.instance.removeObserver(this);
    _emailFocusNode.removeListener(_handleFieldFocus);
    _passwordFocusNode.removeListener(_handleFieldFocus);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _scrollController.dispose();
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
              title: const Text(
                'Reset password',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: PulseClockColors.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Enter your work email and we’ll send password reset instructions.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: PulseClockColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    enabled: !sending,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.email],
                    style: _fieldTextStyle,
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
                        fontFamily: 'Inter',
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
              final bool compactWidth = constraints.maxWidth < 360;
              final bool compactHeight = constraints.maxHeight < 720;
              final bool keyboardVisible =
                  _emailFocusNode.hasFocus ||
                  _passwordFocusNode.hasFocus ||
                  MediaQuery.viewInsetsOf(context).bottom > 0;
              return SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  compactWidth ? 12 : 14,
                  6,
                  compactWidth ? 12 : 14,
                  20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 26,
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
                      SizedBox(
                        height: keyboardVisible
                            ? 2
                            : compactHeight
                            ? 10
                            : 38,
                      ),
                      if (!keyboardVisible)
                        Center(
                          child: Column(
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  'assets/branding/workpulse_app_icon.png',
                                  width: 46,
                                  height: 46,
                                ),
                              ),
                              const SizedBox(height: 8),
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
                        ),
                      SizedBox(
                        height: keyboardVisible
                            ? 6
                            : compactHeight
                            ? 14
                            : 18,
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: compactWidth ? 14 : 16,
                          vertical: keyboardVisible
                              ? 14
                              : compactHeight
                              ? 18
                              : 20,
                        ),
                        decoration: BoxDecoration(
                          color: PulseClockColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  'Welcome back',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    height: 1.12,
                                    letterSpacing: -0.6,
                                    color: PulseClockColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Sign in with your organisation account.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.4,
                                    color: PulseClockColors.textSecondary,
                                  ),
                                ),
                                SizedBox(height: compactHeight ? 16 : 20),
                                TextFormField(
                                  controller: _emailController,
                                  focusNode: _emailFocusNode,
                                  enabled: !_isSubmitting,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const <String>[
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  autocorrect: false,
                                  style: _fieldTextStyle,
                                  validator: (String? value) =>
                                      _looksLikeEmail(value?.trim() ?? '')
                                      ? null
                                      : 'Enter a valid work email address.',
                                  decoration: _inputDecoration(
                                    label: 'Work email',
                                    icon: Icons.mail_outline_rounded,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocusNode,
                                  enabled: !_isSubmitting,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const <String>[
                                    AutofillHints.password,
                                  ],
                                  style: _fieldTextStyle,
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
                                            size: 20,
                                            color: const Color(0xFF718096),
                                          ),
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 6),
                                _LoginOptions(
                                  compact: compactWidth,
                                  rememberEmail: _rememberEmail,
                                  enabled: !_isSubmitting,
                                  onRememberChanged: (bool value) =>
                                      setState(() => _rememberEmail = value),
                                  onForgotPassword: _showForgotPassword,
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
                                            fontFamily: 'Inter',
                                            color: const Color(0xFFB42318),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          PulseClockColors.actionBlue,
                                      foregroundColor: PulseClockColors.surface,
                                      disabledBackgroundColor: PulseClockColors
                                          .actionBlue
                                          .withValues(alpha: 0.55),
                                      elevation: 0,
                                      textStyle: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(11),
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
                      const SizedBox(height: 14),
                      Center(
                        child: const Text(
                          'Need access? Contact your HR team.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                            color: Color(0xFFC9CED8),
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
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF718096)),
      prefixIconConstraints: const BoxConstraints(minWidth: 46),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: PulseClockColors.textSecondary,
      ),
      floatingLabelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: PulseClockColors.actionBlue,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD7DEE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD7DEE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: PulseClockColors.actionBlue,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD92D20)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD92D20), width: 1.4),
      ),
      errorStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  static const TextStyle _fieldTextStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: PulseClockColors.textPrimary,
  );

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
