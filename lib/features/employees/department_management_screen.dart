import 'package:flutter/material.dart';
import 'package:pulseclock/features/employees/data/employee_management_service.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class DepartmentManagementScreen extends StatefulWidget {
  const DepartmentManagementScreen({super.key});

  @override
  State<DepartmentManagementScreen> createState() =>
      _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState
    extends State<DepartmentManagementScreen> {
  final EmployeeManagementService _service = EmployeeManagementService();

  bool _isLoading = true;
  String? _errorMessage;
  List<WorkPulseDepartment> _departments = const <WorkPulseDepartment>[];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final List<WorkPulseDepartment> departments = await _service
          .fetchDepartments();
      if (!mounted) {
        return;
      }
      setState(() {
        _departments = departments;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load departments right now.';
      });
    }
  }

  Future<void> _openDepartmentDialog({WorkPulseDepartment? department}) async {
    final TextEditingController controller = TextEditingController(
      text: department?.name ?? '',
    );
    bool isActive = department?.isActive ?? true;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: PulseClockColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                department == null ? 'Add Department' : 'Edit Department',
                style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Department Name',
                      counterText: '',
                      filled: true,
                      fillColor: PulseClockColors.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (department != null)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Department'),
                      value: isActive,
                      activeTrackColor: PulseClockColors.actionBlue,
                      onChanged: (bool value) {
                        setDialogState(() {
                          isActive = value;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final String name = controller.text.trim();
                          if (name.length < 2) {
                            ScaffoldMessenger.of(this.context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Department name must contain at least 2 characters.',
                                  ),
                                ),
                              );
                            return;
                          }
                          setDialogState(() {
                            isSaving = true;
                          });
                          try {
                            if (department == null) {
                              await _service.createDepartment(name);
                            } else {
                              await _service.updateDepartment(
                                department: department,
                                name: name,
                                isActive: isActive,
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            await _loadDepartments();
                          } catch (error) {
                            if (!mounted) {
                              return;
                            }
                            setDialogState(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(this.context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error.toString().toLowerCase().contains(
                                          'duplicate',
                                        )
                                        ? 'A department with that name already exists.'
                                        : 'Unable to save this department.',
                                  ),
                                ),
                              );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PulseClockColors.actionBlue,
                    foregroundColor: PulseClockColors.surface,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PulseClockColors.surface,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: const Text('Departments'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDepartmentDialog(),
        backgroundColor: PulseClockColors.actionBlue,
        foregroundColor: PulseClockColors.surface,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Department'),
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
        child: SafeArea(top: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: PulseClockColors.onBackgroundPrimary,
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: PulseClockTextStyles.cardSubtitle,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loadDepartments,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_departments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SurfaceCard(
            child: Text(
              'No departments have been added yet.',
              textAlign: TextAlign.center,
              style: PulseClockTextStyles.cardSubtitle,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDepartments,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
        itemCount: _departments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 9),
        itemBuilder: (BuildContext context, int index) {
          final WorkPulseDepartment department = _departments[index];
          return Material(
            color: PulseClockColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _openDepartmentDialog(department: department),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        department.name,
                        style: PulseClockTextStyles.cardSubtitle.copyWith(
                          color: PulseClockColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: department.isActive
                            ? PulseClockColors.statusOnDutyBg
                            : PulseClockColors.statusOffDutyBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        department.isActive ? 'Active' : 'Inactive',
                        style: PulseClockTextStyles.cardSubtitle.copyWith(
                          color: department.isActive
                              ? PulseClockColors.statusOnDutyAccent
                              : PulseClockColors.statusOffDutyAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: PulseClockColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
