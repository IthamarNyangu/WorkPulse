import 'package:flutter/material.dart';
import 'package:pulseclock/features/employees/data/employee_management_service.dart';
import 'package:pulseclock/pulseclock/styles.dart';

class SupervisorPicker extends StatefulWidget {
  const SupervisorPicker({
    required this.supervisors,
    required this.selectedId,
    super.key,
  });

  final List<ManagedEmployeeProfile> supervisors;
  final String? selectedId;

  @override
  State<SupervisorPicker> createState() => _SupervisorPickerState();
}

class _SupervisorPickerState extends State<SupervisorPicker> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<ManagedEmployeeProfile> get _filteredSupervisors {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.supervisors;
    return widget.supervisors
        .where((ManagedEmployeeProfile supervisor) {
          return <String>[
            supervisor.fullName,
            supervisor.employeeId,
            supervisor.email,
            supervisor.departmentName ?? '',
            supervisor.jobTitle ?? '',
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ManagedEmployeeProfile> supervisors = _filteredSupervisors;
    final double keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final double availableHeight =
        MediaQuery.sizeOf(context).height - keyboardHeight;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 14, 18, keyboardHeight + 14),
        child: SizedBox(
          height: availableHeight * 0.68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PulseClockColors.cardBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Select Primary Supervisor',
                style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search name, ID, department, or email',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: PulseClockColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: PulseClockColors.cardBorder,
                    ),
                  ),
                ),
                onChanged: (String value) => setState(() => _query = value),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.person_off_outlined),
                      title: const Text('No Supervisor Assigned'),
                      trailing: widget.selectedId == null
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: PulseClockColors.actionBlue,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                    const Divider(height: 1),
                    if (supervisors.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'No supervisors match your search.',
                          textAlign: TextAlign.center,
                          style: PulseClockTextStyles.cardSubtitle,
                        ),
                      )
                    else
                      ...supervisors.map(
                        (ManagedEmployeeProfile supervisor) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          title: Text(
                            supervisor.fullName,
                            style: PulseClockTextStyles.cardSubtitle.copyWith(
                              color: PulseClockColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            <String>[
                              supervisor.employeeId,
                              if (supervisor.departmentName != null)
                                supervisor.departmentName!,
                              supervisor.email,
                            ].join(' | '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PulseClockTextStyles.cardSubtitle.copyWith(
                              fontSize: 12,
                            ),
                          ),
                          trailing: widget.selectedId == supervisor.id
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: PulseClockColors.actionBlue,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(supervisor.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
