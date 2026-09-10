import 'dart:math';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulseclock/features/attendance/location/office_location_service.dart';
import 'package:pulseclock/features/employees/data/employee_management_service.dart';
import 'package:pulseclock/features/employees/widgets/office_picker.dart';
import 'package:pulseclock/features/employees/widgets/job_title_picker.dart';
import 'package:pulseclock/features/employees/widgets/supervisor_picker.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeCreateScreen extends StatefulWidget {
  const EmployeeCreateScreen({
    required this.data,
    required this.currentRoles,
    super.key,
  });

  final EmployeeManagementData data;
  final List<String> currentRoles;

  @override
  State<EmployeeCreateScreen> createState() => _EmployeeCreateScreenState();
}

class _EmployeeCreateScreenState extends State<EmployeeCreateScreen> {
  static const String _noneValue = '';
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final EmployeeManagementService _service = EmployeeManagementService();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _departmentId;
  String? _jobTitle;
  String? _usualOfficeId;
  String? _supervisorId;
  final Set<String> _roles = <String>{'employee'};
  bool _isActive = true;
  bool _obscurePassword = true;
  bool _isSaving = false;

  bool get _isAdmin => widget.currentRoles.contains('admin');

  List<WorkPulseDepartment> get _departments => widget.data.departments
      .where((WorkPulseDepartment item) => item.isActive)
      .toList(growable: false);

  List<WorkPulseJobTitle> get _jobTitles => widget.data.jobTitles
      .where((WorkPulseJobTitle item) => item.isActive)
      .toList(growable: false);

  List<OfficeLocation> get _offices => widget.data.offices
      .where((OfficeLocation item) => item.isActive)
      .toList(growable: false);

  OfficeLocation? get _selectedOffice {
    for (final OfficeLocation office in _offices) {
      if (office.id == _usualOfficeId) return office;
    }
    return null;
  }

  ManagedEmployeeProfile? get _selectedSupervisor {
    for (final ManagedEmployeeProfile supervisor in widget.data.supervisors) {
      if (supervisor.id == _supervisorId) return supervisor;
    }
    return null;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _employeeIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectSupervisor() async {
    final String? selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PulseClockColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext context) => SupervisorPicker(
        supervisors: widget.data.supervisors,
        selectedId: _supervisorId,
      ),
    );
    if (!mounted || selectedId == null) return;
    setState(() => _supervisorId = selectedId.isEmpty ? null : selectedId);
  }

  Future<void> _selectOffice() async {
    final String? selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PulseClockColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext context) =>
          OfficePicker(offices: _offices, selectedId: _usualOfficeId),
    );
    if (selectedId == null || !mounted) return;
    setState(() => _usualOfficeId = selectedId.isEmpty ? null : selectedId);
  }

  Future<void> _selectJobTitle() async {
    final String? selectedName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PulseClockColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext context) =>
          JobTitlePicker(jobTitles: _jobTitles, selectedName: _jobTitle),
    );
    if (!mounted || selectedName == null) return;
    setState(() => _jobTitle = selectedName);
  }

  void _generateTemporaryPassword() {
    const String upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const String lower = 'abcdefghijkmnopqrstuvwxyz';
    const String digits = '23456789';
    const String symbols = '!@#%';
    final Random random = Random.secure();
    final List<String> characters = <String>[
      upper[random.nextInt(upper.length)],
      lower[random.nextInt(lower.length)],
      digits[random.nextInt(digits.length)],
      symbols[random.nextInt(symbols.length)],
    ];
    const String allCharacters = upper + lower + digits + symbols;
    while (characters.length < 12) {
      characters.add(allCharacters[random.nextInt(allCharacters.length)]);
    }
    characters.shuffle(random);
    final String password = characters.join();
    setState(() {
      _passwordController.text = password;
      _confirmPasswordController.text = password;
      _obscurePassword = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Temporary password generated. Share it securely.'),
        ),
      );
  }

  void _setRole(String role, bool selected) {
    setState(() {
      selected ? _roles.add(role) : _roles.remove(role);
      _roles.add('employee');
    });
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    if (_jobTitle == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Select a job title.')));
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Create Employee Account?'),
        content: Text(
          'Create a WorkPulse login for ${_fullNameController.text.trim()} '
          'using ${_emailController.text.trim().toLowerCase()}?\n\n'
          'Share the temporary password securely. WorkPulse does not store it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await _service.createEmployee(
        email: _emailController.text,
        temporaryPassword: _passwordController.text,
        employeeId: _employeeIdController.text,
        fullName: _fullNameController.text,
        jobTitle: _jobTitle,
        departmentId: _departmentId,
        usualOfficeLocationId: _usualOfficeId,
        supervisorId: _supervisorId,
        roles: _roles.toList(growable: false),
        isActive: _isActive,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee account created successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_friendlyCreateError(error))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: const Text('Add Employee'),
      ),
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PulseClockColors.appBackground,
              PulseClockColors.appBackgroundDeep,
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.paddingOf(context).bottom + 28,
            ),
            children: [
              _section(
                title: 'Account Details',
                children: [
                  _textField(
                    controller: _fullNameController,
                    label: 'Full Name',
                    maxLength: 120,
                    validator: (String? value) =>
                        (value?.trim().length ?? 0) < 2
                        ? 'Enter the employee full name.'
                        : null,
                  ),
                  _textField(
                    controller: _employeeIdController,
                    label: 'Employee ID',
                    maxLength: 40,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9._/-]'),
                      ),
                    ],
                    validator: (String? value) =>
                        RegExp(
                          r'^[A-Za-z0-9][A-Za-z0-9._/-]{1,39}$',
                        ).hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Use 2-40 letters, numbers, dots, slashes, _ or -.',
                  ),
                  _textField(
                    controller: _emailController,
                    label: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    validator: (String? value) =>
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Enter a valid email address.',
                  ),
                  _textField(
                    controller: _passwordController,
                    label: 'Temporary Password',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    validator: (String? value) => (value?.length ?? 0) < 8
                        ? 'Use at least 8 characters.'
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _generateTemporaryPassword,
                      icon: const Icon(Icons.password_rounded),
                      label: const Text('Generate temporary password'),
                    ),
                  ),
                  _textField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Temporary Password',
                    obscureText: _obscurePassword,
                    validator: (String? value) =>
                        value != _passwordController.text
                        ? 'The passwords do not match.'
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _section(
                title: 'Work Assignment',
                children: [
                  InkWell(
                    onTap: _selectJobTitle,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _inputDecoration('Job Title'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _jobTitle ?? 'Select Job Title',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded),
                        ],
                      ),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _departmentId ?? _noneValue,
                    isExpanded: true,
                    decoration: _inputDecoration('Department'),
                    items: [
                      const DropdownMenuItem(
                        value: _noneValue,
                        child: Text('No Department'),
                      ),
                      ..._departments.map(
                        (WorkPulseDepartment department) => DropdownMenuItem(
                          value: department.id,
                          child: Text(department.name),
                        ),
                      ),
                    ],
                    onChanged: (String? value) => setState(
                      () => _departmentId = value == _noneValue ? null : value,
                    ),
                  ),
                  InkWell(
                    onTap: _selectOffice,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _inputDecoration('Usual Work Site'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedOffice?.officeName ??
                                  'No Usual Work Site',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.search_rounded),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _selectSupervisor,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _inputDecoration('Primary Supervisor'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedSupervisor?.fullName ??
                                  'No Supervisor Assigned',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.search_rounded),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _section(
                title: 'Access & Status',
                children: [
                  if (_isAdmin) ...[
                    _roleTile('Employee', 'employee', enabled: false),
                    _roleTile('Supervisor', 'supervisor'),
                    _roleTile('HR', 'hr'),
                    _roleTile('Administrator', 'admin'),
                    const Divider(height: 20),
                  ] else
                    Text(
                      'HR-created accounts receive standard employee access. '
                      'An administrator can grant additional roles later.',
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active Account'),
                    subtitle: const Text('Employee can sign in immediately.'),
                    value: _isActive,
                    onChanged: (bool value) =>
                        setState(() => _isActive = value),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: PulseClockColors.surface,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(
                    _isSaving ? 'Creating Account...' : 'Create Employee',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PulseClockColors.actionBlue,
                    foregroundColor: PulseClockColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 14),
          ...children.expand((Widget child) sync* {
            yield child;
            if (child != children.last) yield const SizedBox(height: 12);
          }),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    int? maxLength,
    TextInputType? keyboardType,
    bool autocorrect = true,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      autocorrect: autocorrect,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: _inputDecoration(
        label,
      ).copyWith(counterText: '', suffixIcon: suffixIcon),
    );
  }

  Widget _roleTile(String label, String role, {bool enabled = true}) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: _roles.contains(role),
      onChanged: enabled
          ? (bool? value) => _setRole(role, value ?? false)
          : null,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: PulseClockColors.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PulseClockColors.cardBorder),
      ),
    );
  }
}

String _friendlyCreateError(Object error) {
  if (error is FunctionException) {
    final dynamic details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
  }
  final String message = error.toString();
  final Match? stateMessage = RegExp(r'Bad state: (.+)$').firstMatch(message);
  if (stateMessage != null) return stateMessage.group(1)!;
  return 'Unable to create the employee account right now.';
}
