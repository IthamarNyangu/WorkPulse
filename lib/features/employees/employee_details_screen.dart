import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulseclock/features/attendance/location/office_location_service.dart';
import 'package:pulseclock/features/employees/data/employee_management_service.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class EmployeeDetailsScreen extends StatelessWidget {
  const EmployeeDetailsScreen({
    required this.employee,
    required this.departments,
    required this.offices,
    required this.supervisors,
    required this.currentRole,
    super.key,
  });

  final ManagedEmployeeProfile employee;
  final List<WorkPulseDepartment> departments;
  final List<OfficeLocation> offices;
  final List<ManagedEmployeeProfile> supervisors;
  final String currentRole;

  bool get _canEdit =>
      (currentRole == 'hr' && employee.role != 'admin') ||
      currentRole == 'admin';

  Future<void> _openEdit(BuildContext context) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => EmployeeEditScreen(
              employee: employee,
              departments: departments,
              offices: offices,
              supervisors: supervisors,
              currentRole: currentRole,
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (saved == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: const Text('Employee Details'),
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
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              children: [
                SurfaceCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: PulseClockColors.actionBlueSoft,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: PulseClockColors.actionBlue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  employee.fullName,
                                  style: PulseClockTextStyles.cardTitle
                                      .copyWith(fontSize: 20),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  employee.employeeId,
                                  style: PulseClockTextStyles.cardSubtitle,
                                ),
                              ],
                            ),
                          ),
                          _AccountStatusBadge(isActive: employee.isActive),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _EmployeeDetailRow(label: 'Email', value: employee.email),
                      _EmployeeDetailRow(
                        label: 'Role',
                        value: employee.roleLabel,
                      ),
                      _EmployeeDetailRow(
                        label: 'Job Title',
                        value: _valueOrDash(employee.jobTitle),
                      ),
                      _EmployeeDetailRow(
                        label: 'Department',
                        value: _valueOrDash(employee.departmentName),
                      ),
                      _EmployeeDetailRow(
                        label: 'Usual Office',
                        value: _valueOrDash(employee.usualOfficeName),
                      ),
                      _EmployeeDetailRow(
                        label: 'Primary Supervisor',
                        value: _valueOrDash(employee.supervisorName),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                if (_canEdit) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openEdit(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PulseClockColors.actionBlue,
                        foregroundColor: PulseClockColors.surface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 19),
                      label: const Text('Edit Employee'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _valueOrDash(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? '--' : trimmed;
  }
}

class EmployeeEditScreen extends StatefulWidget {
  const EmployeeEditScreen({
    required this.employee,
    required this.departments,
    required this.offices,
    required this.supervisors,
    required this.currentRole,
    super.key,
  });

  final ManagedEmployeeProfile employee;
  final List<WorkPulseDepartment> departments;
  final List<OfficeLocation> offices;
  final List<ManagedEmployeeProfile> supervisors;
  final String currentRole;

  @override
  State<EmployeeEditScreen> createState() => _EmployeeEditScreenState();
}

class _EmployeeEditScreenState extends State<EmployeeEditScreen> {
  static const String _noneValue = '';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final EmployeeManagementService _service = EmployeeManagementService();

  late final TextEditingController _fullNameController;
  late final TextEditingController _employeeIdController;
  late final TextEditingController _jobTitleController;
  late String? _departmentId;
  late String? _usualOfficeId;
  late String? _supervisorId;
  late String _role;
  late bool _isActive;
  bool _isSaving = false;

  bool get _canManageRole => widget.currentRole == 'admin';

  bool get _canManageAccount =>
      widget.currentRole == 'hr' || widget.currentRole == 'admin';

  List<WorkPulseDepartment> get _activeDepartments => widget.departments
      .where(
        (WorkPulseDepartment department) =>
            department.isActive ||
            department.id == widget.employee.departmentId,
      )
      .toList(growable: false);

  List<OfficeLocation> get _activeOffices => widget.offices
      .where(
        (OfficeLocation office) =>
            office.isActive ||
            office.id == widget.employee.usualOfficeLocationId,
      )
      .toList(growable: false);

  List<ManagedEmployeeProfile> get _availableSupervisors => widget.supervisors
      .where(
        (ManagedEmployeeProfile supervisor) =>
            supervisor.id != widget.employee.id && supervisor.isActive,
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.employee.fullName);
    _employeeIdController = TextEditingController(
      text: widget.employee.employeeId,
    );
    _jobTitleController = TextEditingController(
      text: widget.employee.jobTitle ?? '',
    );
    _departmentId = widget.employee.departmentId;
    _usualOfficeId = widget.employee.usualOfficeLocationId;
    _supervisorId =
        _availableSupervisors.any(
          (ManagedEmployeeProfile supervisor) =>
              supervisor.id == widget.employee.supervisorId,
        )
        ? widget.employee.supervisorId
        : null;
    _role = widget.employee.role;
    _isActive = widget.employee.isActive;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _employeeIdController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      await _service.updateEmployee(
        employee: widget.employee,
        employeeId: _employeeIdController.text,
        fullName: _fullNameController.text,
        jobTitle: _jobTitleController.text,
        departmentId: _departmentId,
        usualOfficeLocationId: _usualOfficeId,
        supervisorId: _supervisorId,
        role: _role,
        isActive: _isActive,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_friendlyManagementError(error))),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: const Text('Edit Employee'),
      ),
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: Container(
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
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employee Information',
                        style: PulseClockTextStyles.cardTitle.copyWith(
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fullNameController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 120,
                        decoration: _inputDecoration('Full Name'),
                        validator: (String? value) {
                          final String text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Enter the employee full name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _employeeIdController,
                        maxLength: 40,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9._/-]'),
                          ),
                        ],
                        decoration: _inputDecoration('Employee ID'),
                        validator: (String? value) {
                          final String text = value?.trim() ?? '';
                          if (!RegExp(
                            r'^[A-Za-z0-9][A-Za-z0-9._/-]{1,39}$',
                          ).hasMatch(text)) {
                            return 'Use 2-40 letters, numbers, ., _, /, or -.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _jobTitleController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 120,
                        decoration: _inputDecoration('Job Title (Optional)'),
                        validator: (String? value) {
                          final String text = value?.trim() ?? '';
                          if (text.isNotEmpty && text.length < 2) {
                            return 'Job title must contain at least 2 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _departmentId ?? _noneValue,
                        isExpanded: true,
                        decoration: _inputDecoration('Department'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: _noneValue,
                            child: Text('No Department'),
                          ),
                          ..._activeDepartments.map(
                            (WorkPulseDepartment department) =>
                                DropdownMenuItem<String>(
                                  value: department.id,
                                  child: Text(
                                    department.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                          ),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            _departmentId = value == _noneValue ? null : value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _usualOfficeId ?? _noneValue,
                        isExpanded: true,
                        decoration: _inputDecoration('Usual Office'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: _noneValue,
                            child: Text('No Usual Office'),
                          ),
                          ..._activeOffices.map(
                            (OfficeLocation office) => DropdownMenuItem<String>(
                              value: office.id,
                              child: Text(
                                office.officeName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            _usualOfficeId = value == _noneValue ? null : value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _supervisorId ?? _noneValue,
                        isExpanded: true,
                        decoration: _inputDecoration('Primary Supervisor'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: _noneValue,
                            child: Text('No Supervisor Assigned'),
                          ),
                          ..._availableSupervisors.map(
                            (ManagedEmployeeProfile supervisor) =>
                                DropdownMenuItem<String>(
                                  value: supervisor.id,
                                  child: Text(
                                    supervisor.fullName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                          ),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            _supervisorId = value == _noneValue ? null : value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                if (_canManageRole || _canManageAccount) ...[
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Access & Status',
                          style: PulseClockTextStyles.cardTitle.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_canManageRole) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _role,
                            decoration: _inputDecoration('Role'),
                            items: const [
                              DropdownMenuItem(
                                value: 'employee',
                                child: Text('Employee'),
                              ),
                              DropdownMenuItem(
                                value: 'supervisor',
                                child: Text('Supervisor'),
                              ),
                              DropdownMenuItem(value: 'hr', child: Text('HR')),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Administrator'),
                              ),
                            ],
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(() {
                                  _role = value;
                                });
                              }
                            },
                          ),
                          if (_canManageAccount) const SizedBox(height: 10),
                        ],
                        if (_canManageAccount)
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Active Account',
                              style: PulseClockTextStyles.cardSubtitle.copyWith(
                                color: PulseClockColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              _isActive
                                  ? 'Employee can continue using WorkPulse.'
                                  : 'Employee is marked inactive.',
                              style: PulseClockTextStyles.cardSubtitle.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            value: _isActive,
                            activeTrackColor: PulseClockColors.actionBlue,
                            onChanged: (bool value) {
                              setState(() {
                                _isActive = value;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PulseClockColors.actionBlue,
                      foregroundColor: PulseClockColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: PulseClockColors.surface,
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      counterText: '',
      filled: true,
      fillColor: PulseClockColors.surfaceMuted,
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
}

class _EmployeeDetailRow extends StatelessWidget {
  const _EmployeeDetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                color: PulseClockColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountStatusBadge extends StatelessWidget {
  const _AccountStatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? PulseClockColors.statusOnDutyBg
            : PulseClockColors.statusOffDutyBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: PulseClockTextStyles.cardSubtitle.copyWith(
          color: isActive
              ? PulseClockColors.statusOnDutyAccent
              : PulseClockColors.statusOffDutyAccent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _friendlyManagementError(Object error) {
  final String message = error.toString();
  const List<String> knownMessages = [
    'You are not authorised to manage employee profiles.',
    'Supervisors cannot edit HR or administrator profiles.',
    'You cannot deactivate your own account.',
    'Employee ID contains unsupported characters.',
    'Select an active department.',
    'Select an active usual office.',
  ];
  for (final String knownMessage in knownMessages) {
    if (message.contains(knownMessage)) {
      return knownMessage;
    }
  }
  if (message.contains('profiles_employee_id_key') ||
      message.toLowerCase().contains('duplicate key')) {
    return 'That employee ID is already in use.';
  }
  return 'Unable to update this employee right now.';
}
