import 'package:flutter/material.dart';
import 'package:pulseclock/features/supervisor/attendance/data/supervisor_attendance_service.dart';
import 'package:pulseclock/features/supervisor/attendance/presentation/supervisor_attendance_reports_screen.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

enum _SupervisorAttendanceFilter {
  all,
  noClockIn,
  onDuty,
  completed,
  absent,
  onLeave,
  leavePending,
  missedPunch,
  correctionPending,
  locationExceptions,
}

extension _SupervisorAttendanceFilterLabels on _SupervisorAttendanceFilter {
  String get label {
    switch (this) {
      case _SupervisorAttendanceFilter.all:
        return 'All';
      case _SupervisorAttendanceFilter.noClockIn:
        return 'No Clock In';
      case _SupervisorAttendanceFilter.onDuty:
        return 'On Duty';
      case _SupervisorAttendanceFilter.completed:
        return 'Completed';
      case _SupervisorAttendanceFilter.absent:
        return 'Absent';
      case _SupervisorAttendanceFilter.onLeave:
        return 'On Leave';
      case _SupervisorAttendanceFilter.leavePending:
        return 'Leave Pending';
      case _SupervisorAttendanceFilter.missedPunch:
        return 'Missed Punch';
      case _SupervisorAttendanceFilter.correctionPending:
        return 'Correction Pending';
      case _SupervisorAttendanceFilter.locationExceptions:
        return 'Location Exceptions';
    }
  }

  bool matches(SupervisorAttendanceEmployeeRecord record) {
    switch (this) {
      case _SupervisorAttendanceFilter.all:
        return true;
      case _SupervisorAttendanceFilter.noClockIn:
        return record.status == SupervisorAttendanceStatus.noClockIn;
      case _SupervisorAttendanceFilter.onDuty:
        return record.status == SupervisorAttendanceStatus.onDuty;
      case _SupervisorAttendanceFilter.completed:
        return record.status == SupervisorAttendanceStatus.completed;
      case _SupervisorAttendanceFilter.absent:
        return record.status == SupervisorAttendanceStatus.absent;
      case _SupervisorAttendanceFilter.onLeave:
        return record.status == SupervisorAttendanceStatus.onLeave;
      case _SupervisorAttendanceFilter.leavePending:
        return record.status == SupervisorAttendanceStatus.leavePending;
      case _SupervisorAttendanceFilter.missedPunch:
        return record.status == SupervisorAttendanceStatus.missedPunch;
      case _SupervisorAttendanceFilter.correctionPending:
        return record.status == SupervisorAttendanceStatus.correctionPending;
      case _SupervisorAttendanceFilter.locationExceptions:
        return record.hasLocationException;
    }
  }
}

class SupervisorAttendanceDashboardScreen extends StatefulWidget {
  const SupervisorAttendanceDashboardScreen({super.key});

  @override
  State<SupervisorAttendanceDashboardScreen> createState() =>
      _SupervisorAttendanceDashboardScreenState();
}

class _SupervisorAttendanceDashboardScreenState
    extends State<SupervisorAttendanceDashboardScreen> {
  final SupervisorAttendanceService _service = SupervisorAttendanceService();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _searchFieldKey = GlobalKey();

  DateTime _selectedDate = DateTime.now();
  SupervisorAttendanceDay? _day;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  _SupervisorAttendanceFilter _selectedFilter = _SupervisorAttendanceFilter.all;

  List<SupervisorAttendanceEmployeeRecord> get _filteredRecords {
    final SupervisorAttendanceDay? day = _day;
    if (day == null) {
      return const <SupervisorAttendanceEmployeeRecord>[];
    }

    final String query = _searchQuery.trim().toLowerCase();
    return day.records
        .where((SupervisorAttendanceEmployeeRecord record) {
          if (!_selectedFilter.matches(record)) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final String searchableText = <String>[
            record.employeeName,
            record.employeeId,
            record.email,
            record.department ?? '',
            record.status.label,
            record.officeDisplayName ?? '',
            record.clockInLabel,
            record.clockOutLabel,
          ].join(' ').toLowerCase();
          return searchableText.contains(query);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendance({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final SupervisorAttendanceDay day = await _service.fetchAttendanceDay(
        _selectedDate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _day = day;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _day = null;
        _isLoading = false;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 90)),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = _dateOnly(picked);
    });
    await _loadAttendance();
  }

  Future<void> _changeDateBy(int days) async {
    setState(() {
      _selectedDate = _dateOnly(_selectedDate.add(Duration(days: days)));
    });
    await _loadAttendance();
  }

  Future<void> _setDate(DateTime date) async {
    setState(() {
      _selectedDate = _dateOnly(date);
    });
    await _loadAttendance();
  }

  void _openReports() {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => const SupervisorAttendanceReportsScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _openDetails(SupervisorAttendanceEmployeeRecord record) {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => SupervisorAttendanceDetailScreen(record: record),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _revealSearchField() {
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      final BuildContext? searchContext = _searchFieldKey.currentContext;
      if (searchContext == null || !searchContext.mounted) {
        return;
      }
      Scrollable.ensureVisible(
        searchContext,
        alignment: 0.08,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: const Text('Attendance Dashboard'),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PulseClockDimensions.horizontalPadding,
              18,
              PulseClockDimensions.horizontalPadding,
              22,
            ),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            PulseClockColors.onBackgroundPrimary,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: PulseClockColors.statusPendingAccent,
                size: 30,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  color: PulseClockColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _loadAttendance,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final SupervisorAttendanceDay day = _day!;
    final List<SupervisorAttendanceEmployeeRecord> filteredRecords =
        _filteredRecords;

    return RefreshIndicator(
      onRefresh: () => _loadAttendance(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        children: <Widget>[
          Text(
            'Daily employee attendance overview for supervisors.',
            style: PulseClockTextStyles.headerSubtitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),
          _ReportsButton(onTap: _openReports),
          const SizedBox(height: 12),
          _DashboardDateSelector(
            date: _selectedDate,
            onPrevious: () => _changeDateBy(-1),
            onNext: () => _changeDateBy(1),
            onPickDate: _pickDate,
          ),
          const SizedBox(height: 10),
          _DashboardQuickDateChips(
            selectedDate: _selectedDate,
            onToday: () => _setDate(DateTime.now()),
            onYesterday: () =>
                _setDate(DateTime.now().subtract(const Duration(days: 1))),
            onPickDate: _pickDate,
          ),
          const SizedBox(height: 12),
          _SummaryGrid(summary: day.summary),
          const SizedBox(height: 12),
          _SupervisorSearchField(
            key: _searchFieldKey,
            controller: _searchController,
            onTap: _revealSearchField,
            onChanged: (String value) {
              setState(() {
                _searchQuery = value;
              });
            },
            onClear: _searchQuery.isEmpty
                ? null
                : () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
          ),
          const SizedBox(height: 12),
          HistoryFilterChipBar<_SupervisorAttendanceFilter>(
            items: _SupervisorAttendanceFilter.values,
            selectedValue: _selectedFilter,
            labelBuilder: (_SupervisorAttendanceFilter filter) => filter.label,
            onSelected: (_SupervisorAttendanceFilter filter) {
              setState(() {
                _selectedFilter = filter;
              });
            },
          ),
          const SizedBox(height: 10),
          Text(
            '${filteredRecords.length} of ${day.summary.totalEmployees} employees',
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.onBackgroundSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (filteredRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: _EmptyAttendanceDashboardCard(),
            )
          else
            for (
              int index = 0;
              index < filteredRecords.length;
              index++
            ) ...<Widget>[
              _SupervisorAttendanceRecordCard(
                record: filteredRecords[index],
                onTap: () => _openDetails(filteredRecords[index]),
              ),
              if (index != filteredRecords.length - 1)
                const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class SupervisorAttendanceDetailScreen extends StatelessWidget {
  const SupervisorAttendanceDetailScreen({super.key, required this.record});

  final SupervisorAttendanceEmployeeRecord record;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: const Text('Attendance Details'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              PulseClockDimensions.horizontalPadding,
              18,
              PulseClockDimensions.horizontalPadding,
              24,
            ),
            child: Column(
              children: [
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.employeeName,
                                  style: PulseClockTextStyles.cardTitle
                                      .copyWith(fontSize: 22),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Employee ID: ${record.employeeId}',
                                  style: PulseClockTextStyles.cardSubtitle
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SupervisorStatusBadge(status: record.status),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: PulseClockColors.cardBorder),
                      const SizedBox(height: 14),
                      _SupervisorDetailRow(
                        label: 'Date',
                        value: fullDateLabel(record.date),
                      ),
                      const SizedBox(height: 10),
                      _SupervisorDetailRow(
                        label: 'Department',
                        value: _valueOrDash(record.department),
                      ),
                      const SizedBox(height: 10),
                      _SupervisorDetailRow(label: 'Email', value: record.email),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardSectionTitle(
                        icon: Icons.access_time_rounded,
                        title: 'Attendance',
                      ),
                      const SizedBox(height: 14),
                      _SupervisorDetailRow(
                        label: 'Clock In',
                        value: record.clockInLabel,
                      ),
                      const SizedBox(height: 10),
                      _SupervisorDetailRow(
                        label: 'Clock Out',
                        value: record.clockOutLabel,
                      ),
                      const SizedBox(height: 10),
                      _SupervisorDetailRow(
                        label: 'Work Hours',
                        value: record.workHoursLabel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _LocationDetailsCard(
                  title: 'Clock In Location',
                  snapshot: record.clockInLocation,
                ),
                const SizedBox(height: 12),
                _LocationDetailsCard(
                  title: 'Clock Out Location',
                  snapshot: record.clockOutLocation,
                ),
                const SizedBox(height: 12),
                _CommentsCard(record: record),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardDateSelector extends StatelessWidget {
  const _DashboardDateSelector({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderRadius: 14,
      child: Row(
        children: [
          _DateArrowButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPickDate,
              child: Column(
                children: [
                  Text(
                    weekdayName(date),
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dateLabel(date),
                    style: PulseClockTextStyles.cardTitle.copyWith(
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _DateArrowButton(icon: Icons.chevron_right_rounded, onTap: onNext),
          const SizedBox(width: 2),
          IconButton(
            onPressed: onPickDate,
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: PulseClockColors.actionBlue,
            ),
            tooltip: 'Pick date',
          ),
        ],
      ),
    );
  }
}

class _DashboardQuickDateChips extends StatelessWidget {
  const _DashboardQuickDateChips({
    required this.selectedDate,
    required this.onToday,
    required this.onYesterday,
    required this.onPickDate,
  });

  final DateTime selectedDate;
  final VoidCallback onToday;
  final VoidCallback onYesterday;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final DateTime today = _dateOnly(DateTime.now());
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickDateChip(
            label: 'Today',
            isSelected: _dateOnly(selectedDate) == today,
            onTap: onToday,
          ),
          const SizedBox(width: 8),
          _QuickDateChip(
            label: 'Yesterday',
            isSelected: _dateOnly(selectedDate) == yesterday,
            onTap: onYesterday,
          ),
          const SizedBox(width: 8),
          _QuickDateChip(
            label: 'Pick Date',
            isSelected: false,
            onTap: onPickDate,
          ),
        ],
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? PulseClockColors.actionBlue
              : PulseClockColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PulseClockColors.cardBorder),
        ),
        child: Text(
          label,
          style: PulseClockTextStyles.cardSubtitle.copyWith(
            color: isSelected
                ? PulseClockColors.surface
                : PulseClockColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ReportsButton extends StatelessWidget {
  const _ReportsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PulseClockColors.reportAction,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: PulseClockColors.surface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.insert_chart_outlined_rounded,
                  size: 20,
                  color: PulseClockColors.reportAction,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Attendance Reports',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    color: PulseClockColors.surface,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: PulseClockColors.surface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateArrowButton extends StatelessWidget {
  const _DateArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: PulseClockColors.textPrimary),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final SupervisorAttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryMetricCard(
                label: 'Employees',
                value: summary.totalEmployees.toString(),
                color: PulseClockColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryMetricCard(
                label: 'Clocked In',
                value: summary.clockedIn.toString(),
                color: PulseClockColors.actionBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryMetricCard(
                label: 'Clocked Out',
                value: summary.clockedOut.toString(),
                color: PulseClockColors.statusOnDutyAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SummaryMetricCard(
                label: 'Absent',
                value: summary.absent.toString(),
                color: PulseClockColors.statusMissedAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryMetricCard(
                label: 'On Leave',
                value: summary.onLeave.toString(),
                color: PulseClockColors.statusLeaveAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryMetricCard(
                label: 'Exceptions',
                value: summary.locationExceptions.toString(),
                color: PulseClockColors.statusPendingAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PulseClockTextStyles.summaryLabel.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: PulseClockTextStyles.summaryValue.copyWith(
              color: color,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupervisorAttendanceRecordCard extends StatelessWidget {
  const _SupervisorAttendanceRecordCard({
    required this.record,
    required this.onTap,
  });

  final SupervisorAttendanceEmployeeRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _SupervisorStatusStyle statusStyle = _statusStyle(record.status);

    return Material(
      color: PulseClockColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PulseClockColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 62,
                decoration: BoxDecoration(
                  color: statusStyle.foregroundColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            record.employeeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PulseClockTextStyles.cardSubtitle.copyWith(
                              color: PulseClockColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SupervisorStatusBadge(status: record.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.employeeId} | In ${record.clockInLabel} | Out ${record.clockOutLabel} | ${record.workHoursLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (record.hasLocationException) ...<Widget>[
                          const Icon(
                            Icons.location_off_outlined,
                            color: PulseClockColors.statusPendingAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            record.hasLocationException
                                ? 'Location exception'
                                : (record.officeDisplayName ??
                                      _attendanceHint(record)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PulseClockTextStyles.cardSubtitle.copyWith(
                              color: record.hasLocationException
                                  ? PulseClockColors.statusPendingAccent
                                  : PulseClockColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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

class _SupervisorSearchField extends StatelessWidget {
  const _SupervisorSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onTap: onTap,
      textInputAction: TextInputAction.search,
      scrollPadding: const EdgeInsets.only(bottom: 120),
      style: PulseClockTextStyles.cardSubtitle.copyWith(
        color: PulseClockColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Search employee, ID, department, office',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: PulseClockColors.textSecondary,
        ),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(
                  Icons.close_rounded,
                  color: PulseClockColors.textSecondary,
                ),
              ),
        filled: true,
        fillColor: PulseClockColors.surface,
        hintStyle: PulseClockTextStyles.cardSubtitle.copyWith(fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PulseClockColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PulseClockColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: PulseClockColors.actionBlue,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _SupervisorStatusBadge extends StatelessWidget {
  const _SupervisorStatusBadge({required this.status});

  final SupervisorAttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final _SupervisorStatusStyle style = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: PulseClockTextStyles.cardSubtitle.copyWith(
          color: style.foregroundColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LocationDetailsCard extends StatelessWidget {
  const _LocationDetailsCard({required this.title, required this.snapshot});

  final String title;
  final ClockLocationSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final ClockLocationSnapshot? location = snapshot;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardSectionTitle(icon: Icons.location_on_outlined, title: title),
          const SizedBox(height: 14),
          if (location == null)
            Text(
              'No location information captured.',
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                color: PulseClockColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            )
          else ...<Widget>[
            _SupervisorDetailRow(
              label: 'Status',
              value: location.status.label,
              valueColor: _locationStatusColor(location.status),
            ),
            const SizedBox(height: 10),
            _SupervisorDetailRow(
              label: 'GPS Accuracy',
              value: _accuracyLabel(location),
            ),
            const SizedBox(height: 10),
            _SupervisorDetailRow(
              label: location.status == ClockLocationStatus.insideOffice
                  ? 'Verified Office'
                  : 'Nearest Office',
              value: location.officeDisplayName ?? 'Not available',
            ),
            const SizedBox(height: 10),
            _SupervisorDetailRow(
              label: 'Distance',
              value: location.distanceMeters == null
                  ? 'Not available'
                  : _metersLabel(location.distanceMeters!),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentsCard extends StatelessWidget {
  const _CommentsCard({required this.record});

  final SupervisorAttendanceEmployeeRecord record;

  @override
  Widget build(BuildContext context) {
    final String? clockInComment = _trimOrNull(record.clockInComment);
    final String? clockOutComment = _trimOrNull(record.clockOutComment);
    final bool hasComments = clockInComment != null || clockOutComment != null;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardSectionTitle(icon: Icons.notes_rounded, title: 'Comments'),
          const SizedBox(height: 14),
          if (!hasComments)
            Text(
              'No comments captured.',
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                color: PulseClockColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            )
          else ...<Widget>[
            if (clockInComment != null) ...<Widget>[
              _CommentBlock(title: 'Clock In Comment', value: clockInComment),
              if (clockOutComment != null) const SizedBox(height: 12),
            ],
            if (clockOutComment != null)
              _CommentBlock(title: 'Clock Out Comment', value: clockOutComment),
          ],
        ],
      ),
    );
  }
}

class _CommentBlock extends StatelessWidget {
  const _CommentBlock({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PulseClockColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: PulseClockTextStyles.cardSubtitle),
        ],
      ),
    );
  }
}

class _CardSectionTitle extends StatelessWidget {
  const _CardSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: PulseClockColors.textPrimary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 18),
        ),
      ],
    );
  }
}

class _SupervisorDetailRow extends StatelessWidget {
  const _SupervisorDetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 124,
          child: Text(label, style: PulseClockTextStyles.cardSubtitle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: valueColor ?? PulseClockColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyAttendanceDashboardCard extends StatelessWidget {
  const _EmptyAttendanceDashboardCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          const Icon(
            Icons.people_outline_rounded,
            color: PulseClockColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No employee attendance records found.',
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                color: PulseClockColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupervisorStatusStyle {
  const _SupervisorStatusStyle({
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
}

_SupervisorStatusStyle _statusStyle(SupervisorAttendanceStatus status) {
  switch (status) {
    case SupervisorAttendanceStatus.noClockIn:
    case SupervisorAttendanceStatus.nonWorkingDay:
      return const _SupervisorStatusStyle(
        backgroundColor: PulseClockColors.statusOffDutyBg,
        foregroundColor: PulseClockColors.statusOffDutyAccent,
      );
    case SupervisorAttendanceStatus.onDuty:
      return const _SupervisorStatusStyle(
        backgroundColor: Color(0xFFE2F4EA),
        foregroundColor: PulseClockColors.statusOnDutyAccent,
      );
    case SupervisorAttendanceStatus.completed:
      return const _SupervisorStatusStyle(
        backgroundColor: Color(0xFFE1F8EA),
        foregroundColor: Color(0xFF08753A),
      );
    case SupervisorAttendanceStatus.missedPunch:
    case SupervisorAttendanceStatus.absent:
      return const _SupervisorStatusStyle(
        backgroundColor: PulseClockColors.statusMissedBg,
        foregroundColor: PulseClockColors.statusMissedAccent,
      );
    case SupervisorAttendanceStatus.correctionPending:
    case SupervisorAttendanceStatus.leavePending:
      return const _SupervisorStatusStyle(
        backgroundColor: PulseClockColors.statusPendingBg,
        foregroundColor: PulseClockColors.statusPendingAccent,
      );
    case SupervisorAttendanceStatus.onLeave:
      return const _SupervisorStatusStyle(
        backgroundColor: PulseClockColors.statusLeaveBg,
        foregroundColor: PulseClockColors.statusLeaveAccent,
      );
  }
}

Color _locationStatusColor(ClockLocationStatus status) {
  switch (status) {
    case ClockLocationStatus.insideOffice:
      return PulseClockColors.statusOnDutyAccent;
    case ClockLocationStatus.outsideAllOffices:
      return PulseClockColors.statusMissedAccent;
    case ClockLocationStatus.lowAccuracy:
    case ClockLocationStatus.noOfficesConfigured:
      return PulseClockColors.statusPendingAccent;
    case ClockLocationStatus.locationUnavailable:
      return PulseClockColors.textSecondary;
  }
}

String _attendanceHint(SupervisorAttendanceEmployeeRecord record) {
  switch (record.status) {
    case SupervisorAttendanceStatus.noClockIn:
      return 'No attendance action yet';
    case SupervisorAttendanceStatus.nonWorkingDay:
      return 'No scheduled workday';
    case SupervisorAttendanceStatus.onDuty:
      return 'Currently clocked in';
    case SupervisorAttendanceStatus.completed:
      return 'Attendance completed';
    case SupervisorAttendanceStatus.missedPunch:
      return 'Incomplete attendance';
    case SupervisorAttendanceStatus.correctionPending:
      return 'Correction under review';
    case SupervisorAttendanceStatus.leavePending:
      return 'Leave awaiting approval';
    case SupervisorAttendanceStatus.onLeave:
      return 'Approved leave';
    case SupervisorAttendanceStatus.absent:
      return 'No attendance recorded';
  }
}

String _accuracyLabel(ClockLocationSnapshot snapshot) {
  if (snapshot.coordinates == 'Not captured') {
    return 'Not captured';
  }
  return '${snapshot.accuracyMeters.toStringAsFixed(1)} m (${snapshot.accuracyQualityLabel})';
}

String _metersLabel(double value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(2)} km';
  }
  return '${value.round()} m';
}

String _valueOrDash(String? value) {
  final String? trimmed = _trimOrNull(value);
  return trimmed ?? '--';
}

String? _trimOrNull(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _friendlyError(Object error) {
  final String message = error.toString();
  if (message.contains('Only supervisors')) {
    return 'Only supervisors, HR, and admins can view this dashboard.';
  }
  if (message.contains('No active WorkPulse profile')) {
    return 'No active WorkPulse profile found. Sign in again and try this dashboard.';
  }
  return 'Unable to load the attendance dashboard right now.';
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}
