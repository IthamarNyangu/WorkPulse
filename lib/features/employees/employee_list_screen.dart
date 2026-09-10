import 'package:flutter/material.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/features/auth/session/workpulse_session.dart';
import 'package:pulseclock/features/employees/data/employee_management_service.dart';
import 'package:pulseclock/features/employees/department_management_screen.dart';
import 'package:pulseclock/features/employees/employee_details_screen.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

enum _EmployeeStatusFilter { all, active, inactive }

extension on _EmployeeStatusFilter {
  String get label {
    switch (this) {
      case _EmployeeStatusFilter.all:
        return 'All';
      case _EmployeeStatusFilter.active:
        return 'Active';
      case _EmployeeStatusFilter.inactive:
        return 'Inactive';
    }
  }

  bool matches(ManagedEmployeeProfile employee) {
    switch (this) {
      case _EmployeeStatusFilter.all:
        return true;
      case _EmployeeStatusFilter.active:
        return employee.isActive;
      case _EmployeeStatusFilter.inactive:
        return !employee.isActive;
    }
  }
}

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key, this.profile});

  final WorkPulseUserProfile? profile;

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  static const int _pageSize = 12;
  static const Set<String> _managerRoles = <String>{
    'supervisor',
    'hr',
    'admin',
  };

  final EmployeeManagementService _service = EmployeeManagementService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _hasStartedLoading = false;
  String? _errorMessage;
  String _currentRole = 'employee';
  String _searchQuery = '';
  _EmployeeStatusFilter _statusFilter = _EmployeeStatusFilter.all;
  int _page = 0;
  EmployeeManagementData? _data;

  bool get _canManageDepartments =>
      _currentRole == 'hr' || _currentRole == 'admin';

  List<ManagedEmployeeProfile> get _filteredEmployees {
    final List<ManagedEmployeeProfile> employees =
        _data?.employees ?? const <ManagedEmployeeProfile>[];
    final String query = _searchQuery.trim().toLowerCase();
    return employees
        .where((ManagedEmployeeProfile employee) {
          if (!_statusFilter.matches(employee)) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          final String searchable = <String>[
            employee.fullName,
            employee.employeeId,
            employee.email,
            employee.roleLabel,
            employee.jobTitle ?? '',
            employee.departmentName ?? '',
            employee.usualOfficeName ?? '',
          ].join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  List<ManagedEmployeeProfile> get _pagedEmployees {
    final List<ManagedEmployeeProfile> filtered = _filteredEmployees;
    final int start = _page * _pageSize;
    if (start >= filtered.length) {
      return const <ManagedEmployeeProfile>[];
    }
    return filtered.sublist(
      start,
      (start + _pageSize).clamp(0, filtered.length),
    );
  }

  int get _pageCount {
    final int count = _filteredEmployees.length;
    return count == 0 ? 1 : ((count - 1) ~/ _pageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStartedLoading) {
      _hasStartedLoading = true;
      _loadEmployees();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final WorkPulseUserProfile? sessionProfile =
          widget.profile ??
          WorkPulseSessionScope.maybeProfileOf(context, listen: false);
      final WorkPulseUserProfile? profile =
          sessionProfile ?? await AuthService().fetchCurrentProfile();
      if (profile == null || !profile.hasAnyRole(_managerRoles)) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Only supervisors, HR, and administrators can view employees.';
        });
        return;
      }

      final EmployeeManagementData data = await _service.fetchManagementData(
        currentUserId: profile.id,
        currentRoles: profile.roles,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentRole = profile.effectiveRole;
        _data = data;
        _page = 0;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error.toString();
      setState(() {
        _isLoading = false;
        _errorMessage =
            message.contains('department_id') ||
                message.contains('departments') ||
                message.contains('employee_supervisor_assignments')
            ? 'Employee management is not configured yet. Run the employee and role-scope SQL migrations in Supabase.'
            : 'Unable to load employees right now.';
      });
    }
  }

  Future<void> _openEmployee(ManagedEmployeeProfile employee) async {
    final EmployeeManagementData? data = _data;
    if (data == null) {
      return;
    }
    final bool? changed = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => EmployeeDetailsScreen(
              employee: employee,
              departments: data.departments,
              offices: data.offices,
              supervisors: data.supervisors,
              currentRole: _currentRole,
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    if (changed == true) {
      await _loadEmployees();
    }
  }

  Future<void> _openDepartments() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => const DepartmentManagementScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    await _loadEmployees();
  }

  void _updateFilter(_EmployeeStatusFilter filter) {
    setState(() {
      _statusFilter = filter;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: const Text('Employees'),
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
                  onPressed: _loadEmployees,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final List<ManagedEmployeeProfile> employees = _pagedEmployees;
    return RefreshIndicator(
      onRefresh: _loadEmployees,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          if (_canManageDepartments) ...[
            _DepartmentNavigationCard(onTap: _openDepartments),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _searchController,
            onChanged: (String value) {
              setState(() {
                _searchQuery = value;
                _page = 0;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search name, ID, department, role',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _page = 0;
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: PulseClockColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _EmployeeStatusFilter.values
                .map((_EmployeeStatusFilter filter) {
                  final bool selected = filter == _statusFilter;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: filter == _EmployeeStatusFilter.inactive ? 0 : 8,
                      ),
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            filter.label,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        selected: selected,
                        onSelected: (_) => _updateFilter(filter),
                        selectedColor: PulseClockColors.actionBlue,
                        backgroundColor: PulseClockColors.surface,
                        labelStyle: PulseClockTextStyles.cardSubtitle.copyWith(
                          color: selected
                              ? PulseClockColors.surface
                              : PulseClockColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        side: const BorderSide(
                          color: PulseClockColors.cardBorder,
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          Text(
            '${_filteredEmployees.length} employees',
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.onBackgroundSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (employees.isEmpty)
            SurfaceCard(
              child: Text(
                'No employees match these filters.',
                textAlign: TextAlign.center,
                style: PulseClockTextStyles.cardSubtitle,
              ),
            )
          else
            ...employees.map(
              (ManagedEmployeeProfile employee) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _EmployeeListCard(
                  employee: employee,
                  onTap: () => _openEmployee(employee),
                ),
              ),
            ),
          if (_pageCount > 1) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _page == 0
                        ? null
                        : () {
                            setState(() {
                              _page--;
                            });
                          },
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Page ${_page + 1} of $_pageCount',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    color: PulseClockColors.onBackgroundPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _page >= _pageCount - 1
                        ? null
                        : () {
                            setState(() {
                              _page++;
                            });
                          },
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DepartmentNavigationCard extends StatelessWidget {
  const _DepartmentNavigationCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PulseClockColors.reportActionSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: PulseClockColors.reportActionBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.account_tree_outlined,
                color: PulseClockColors.reportAction,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Manage Departments',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    color: PulseClockColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: PulseClockColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeListCard extends StatelessWidget {
  const _EmployeeListCard({required this.employee, required this.onTap});

  final ManagedEmployeeProfile employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PulseClockColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: employee.isActive
                      ? PulseClockColors.actionBlueSoft
                      : PulseClockColors.statusOffDutyBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: employee.isActive
                      ? PulseClockColors.actionBlue
                      : PulseClockColors.statusOffDutyAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        color: PulseClockColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      <String>[
                        employee.employeeId,
                        employee.departmentName ?? employee.roleLabel,
                      ].join('  |  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: employee.isActive
                      ? PulseClockColors.statusOnDutyAccent
                      : PulseClockColors.navUnselected,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: PulseClockColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
