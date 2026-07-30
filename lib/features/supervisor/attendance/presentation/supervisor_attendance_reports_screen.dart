import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulseclock/features/supervisor/attendance/data/supervisor_attendance_service.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

enum _ReportDateRangeFilter {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  custom,
}

extension _ReportDateRangeFilterLabels on _ReportDateRangeFilter {
  String get label {
    switch (this) {
      case _ReportDateRangeFilter.today:
        return 'Today';
      case _ReportDateRangeFilter.yesterday:
        return 'Yesterday';
      case _ReportDateRangeFilter.thisWeek:
        return 'This Week';
      case _ReportDateRangeFilter.lastWeek:
        return 'Last Week';
      case _ReportDateRangeFilter.thisMonth:
        return 'This Month';
      case _ReportDateRangeFilter.lastMonth:
        return 'Last Month';
      case _ReportDateRangeFilter.custom:
        return 'Custom';
    }
  }
}

enum _ReportStatusFilter {
  all,
  noClockIn,
  nonWorkingDay,
  onDuty,
  completed,
  missedPunch,
  correctionPending,
  leavePending,
  onLeave,
  absent,
  locationExceptions,
}

extension _ReportStatusFilterLabels on _ReportStatusFilter {
  String get label {
    switch (this) {
      case _ReportStatusFilter.all:
        return 'All';
      case _ReportStatusFilter.noClockIn:
        return 'No Clock In';
      case _ReportStatusFilter.nonWorkingDay:
        return 'Non-Working Day';
      case _ReportStatusFilter.onDuty:
        return 'On Duty';
      case _ReportStatusFilter.completed:
        return 'Completed';
      case _ReportStatusFilter.missedPunch:
        return 'Missed Punch';
      case _ReportStatusFilter.correctionPending:
        return 'Correction Pending';
      case _ReportStatusFilter.leavePending:
        return 'Leave Pending';
      case _ReportStatusFilter.onLeave:
        return 'On Leave';
      case _ReportStatusFilter.absent:
        return 'Absent';
      case _ReportStatusFilter.locationExceptions:
        return 'Location Exceptions';
    }
  }

  bool matches(SupervisorAttendanceEmployeeRecord record) {
    switch (this) {
      case _ReportStatusFilter.all:
        return true;
      case _ReportStatusFilter.noClockIn:
        return record.status == SupervisorAttendanceStatus.noClockIn;
      case _ReportStatusFilter.nonWorkingDay:
        return record.status == SupervisorAttendanceStatus.nonWorkingDay;
      case _ReportStatusFilter.onDuty:
        return record.status == SupervisorAttendanceStatus.onDuty;
      case _ReportStatusFilter.completed:
        return record.status == SupervisorAttendanceStatus.completed;
      case _ReportStatusFilter.missedPunch:
        return record.status == SupervisorAttendanceStatus.missedPunch;
      case _ReportStatusFilter.correctionPending:
        return record.status == SupervisorAttendanceStatus.correctionPending;
      case _ReportStatusFilter.leavePending:
        return record.status == SupervisorAttendanceStatus.leavePending;
      case _ReportStatusFilter.onLeave:
        return record.status == SupervisorAttendanceStatus.onLeave;
      case _ReportStatusFilter.absent:
        return record.status == SupervisorAttendanceStatus.absent;
      case _ReportStatusFilter.locationExceptions:
        return record.hasLocationException;
    }
  }
}

class SupervisorAttendanceReportsScreen extends StatefulWidget {
  const SupervisorAttendanceReportsScreen({super.key});

  @override
  State<SupervisorAttendanceReportsScreen> createState() =>
      _SupervisorAttendanceReportsScreenState();
}

class _SupervisorAttendanceReportsScreenState
    extends State<SupervisorAttendanceReportsScreen> {
  static const int _pageSize = 25;

  final SupervisorAttendanceService _service = SupervisorAttendanceService();
  final TextEditingController _searchController = TextEditingController();

  _ReportDateRangeFilter _selectedRange = _ReportDateRangeFilter.thisWeek;
  _ReportStatusFilter _selectedStatus = _ReportStatusFilter.all;
  DateTimeRange _dateRange = _defaultRangeFor(_ReportDateRangeFilter.thisWeek);
  SupervisorAttendanceReport? _report;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _departmentFilter = _allFilterValue;
  String _provinceFilter = _allFilterValue;
  String _officeFilter = _allFilterValue;
  int _page = 0;

  static const String _allFilterValue = 'All';

  List<SupervisorAttendanceEmployeeRecord> get _filteredRecords {
    final SupervisorAttendanceReport? report = _report;
    if (report == null) {
      return const <SupervisorAttendanceEmployeeRecord>[];
    }

    final String query = _searchQuery.trim().toLowerCase();
    return report.records
        .where((SupervisorAttendanceEmployeeRecord record) {
          if (!_selectedStatus.matches(record)) {
            return false;
          }
          if (_departmentFilter != _allFilterValue &&
              record.department != _departmentFilter) {
            return false;
          }
          if (_provinceFilter != _allFilterValue &&
              record.officeProvince != _provinceFilter) {
            return false;
          }
          if (_officeFilter != _allFilterValue &&
              record.officeDisplayName != _officeFilter) {
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
            dateLabel(record.date),
            record.officeDisplayName ?? '',
            record.officeProvince ?? '',
          ].join(' ').toLowerCase();
          return searchableText.contains(query);
        })
        .toList(growable: false);
  }

  List<SupervisorAttendanceEmployeeRecord> get _pagedRecords {
    final List<SupervisorAttendanceEmployeeRecord> records = _filteredRecords;
    if (records.isEmpty) {
      return const <SupervisorAttendanceEmployeeRecord>[];
    }

    final int start = _page * _pageSize;
    if (start >= records.length) {
      return const <SupervisorAttendanceEmployeeRecord>[];
    }
    final int end = (start + _pageSize).clamp(0, records.length);
    return records.sublist(start, end);
  }

  int get _pageCount {
    final int recordCount = _filteredRecords.length;
    if (recordCount == 0) {
      return 1;
    }
    return ((recordCount - 1) ~/ _pageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReport({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final SupervisorAttendanceReport report = await _service
          .fetchAttendanceReport(
            startDate: _dateRange.start,
            endDate: _dateRange.end,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _report = report;
        _isLoading = false;
        _errorMessage = null;
        _page = 0;
        _ensureValidDropdownSelections();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _report = null;
        _isLoading = false;
        _errorMessage = 'Unable to load attendance reports right now.';
      });
    }
  }

  Future<void> _selectDateRange(_ReportDateRangeFilter range) async {
    if (range == _ReportDateRangeFilter.custom) {
      final DateTime now = DateTime.now();
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        initialDateRange: _dateRange,
        firstDate: now.subtract(const Duration(days: 365)),
        lastDate: now,
      );
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _selectedRange = range;
        _dateRange = DateTimeRange(
          start: _dateOnly(picked.start),
          end: _dateOnly(picked.end),
        );
      });
      await _loadReport();
      return;
    }

    setState(() {
      _selectedRange = range;
      _dateRange = _defaultRangeFor(range);
    });
    await _loadReport();
  }

  void _resetPage() {
    if (_page != 0) {
      _page = 0;
    }
  }

  void _ensureValidDropdownSelections() {
    final Set<String> departments = _dropdownValues(
      _report?.records.map((SupervisorAttendanceEmployeeRecord record) {
        return record.department;
      }),
    ).toSet();
    final Set<String> provinces = _dropdownValues(
      _report?.records.map((SupervisorAttendanceEmployeeRecord record) {
        return record.officeProvince;
      }),
    ).toSet();
    final Set<String> offices = _dropdownValues(
      _report?.records.map((SupervisorAttendanceEmployeeRecord record) {
        return record.officeDisplayName;
      }),
    ).toSet();

    if (!departments.contains(_departmentFilter)) {
      _departmentFilter = _allFilterValue;
    }
    if (!provinces.contains(_provinceFilter)) {
      _provinceFilter = _allFilterValue;
    }
    if (!offices.contains(_officeFilter)) {
      _officeFilter = _allFilterValue;
    }
  }

  Future<void> _showCsvExportDialog() async {
    final List<SupervisorAttendanceEmployeeRecord> records = _filteredRecords;
    final String csv = _csvForRecords(records);
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFCFDFE),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Export CSV',
            style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
          ),
          content: Text(
            '${records.length} filtered records are ready. Copy the CSV and paste it into Excel or Google Sheets.',
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                final NavigatorState navigator = Navigator.of(context);
                final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                  this.context,
                );
                navigator.pop();
                await Clipboard.setData(ClipboardData(text: csv));
                if (!mounted) {
                  return;
                }
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('CSV copied to clipboard.')),
                  );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PulseClockColors.actionBlue,
                foregroundColor: PulseClockColors.surface,
              ),
              child: const Text('Copy CSV'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: const Text('Attendance Reports'),
        actions: [
          IconButton(
            onPressed: _report == null ? null : _showCsvExportDialog,
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
          ),
        ],
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
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  color: PulseClockColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadReport, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final List<SupervisorAttendanceEmployeeRecord> filteredRecords =
        _filteredRecords;
    final _ReportSummary summary = _ReportSummary.fromRecords(filteredRecords);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter attendance records by date, employee, department, province, office, and status.',
          style: PulseClockTextStyles.headerSubtitle.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 12),
        HistoryFilterChipBar<_ReportDateRangeFilter>(
          items: _ReportDateRangeFilter.values,
          selectedValue: _selectedRange,
          labelBuilder: (_ReportDateRangeFilter range) => range.label,
          onSelected: _selectDateRange,
        ),
        const SizedBox(height: 10),
        Text(
          _dateRangeLabel(_dateRange),
          style: PulseClockTextStyles.cardSubtitle.copyWith(
            color: PulseClockColors.onBackgroundSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _ReportsSearchField(
          controller: _searchController,
          onChanged: (String value) {
            setState(() {
              _searchQuery = value;
              _resetPage();
            });
          },
          onClear: _searchQuery.isEmpty
              ? null
              : () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _resetPage();
                  });
                },
        ),
        const SizedBox(height: 10),
        HistoryFilterChipBar<_ReportStatusFilter>(
          items: _ReportStatusFilter.values,
          selectedValue: _selectedStatus,
          labelBuilder: (_ReportStatusFilter status) => status.label,
          onSelected: (_ReportStatusFilter status) {
            setState(() {
              _selectedStatus = status;
              _resetPage();
            });
          },
        ),
        const SizedBox(height: 10),
        _ReportDropdownFilters(
          departments: _dropdownValues(
            _report?.records.map((SupervisorAttendanceEmployeeRecord record) {
              return record.department;
            }),
          ),
          provinces: _dropdownValues(
            _report?.records.map((SupervisorAttendanceEmployeeRecord record) {
              return record.officeProvince;
            }),
          ),
          offices: _dropdownValues(
            _report?.records.map((SupervisorAttendanceEmployeeRecord record) {
              return record.officeDisplayName;
            }),
          ),
          selectedDepartment: _departmentFilter,
          selectedProvince: _provinceFilter,
          selectedOffice: _officeFilter,
          onDepartmentChanged: (String value) {
            setState(() {
              _departmentFilter = value;
              _resetPage();
            });
          },
          onProvinceChanged: (String value) {
            setState(() {
              _provinceFilter = value;
              _resetPage();
            });
          },
          onOfficeChanged: (String value) {
            setState(() {
              _officeFilter = value;
              _resetPage();
            });
          },
        ),
        const SizedBox(height: 12),
        _ReportSummaryGrid(summary: summary),
        const SizedBox(height: 10),
        Text(
          '${filteredRecords.length} records',
          style: PulseClockTextStyles.cardSubtitle.copyWith(
            color: PulseClockColors.onBackgroundSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadReport(showLoading: false),
            child: filteredRecords.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const <Widget>[
                      SizedBox(height: 110),
                      _EmptyReportsCard(),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (BuildContext context, int index) {
                      final List<SupervisorAttendanceEmployeeRecord> pageRows =
                          _pagedRecords;
                      if (index == pageRows.length) {
                        return _ReportPaginationControls(
                          page: _page,
                          pageCount: _pageCount,
                          onPrevious: _page == 0
                              ? null
                              : () {
                                  setState(() {
                                    _page--;
                                  });
                                },
                          onNext: _page >= _pageCount - 1
                              ? null
                              : () {
                                  setState(() {
                                    _page++;
                                  });
                                },
                        );
                      }
                      return _ReportRecordCard(record: pageRows[index]);
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 8),
                    itemCount: _pagedRecords.length + (_pageCount > 1 ? 1 : 0),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReportDropdownFilters extends StatelessWidget {
  const _ReportDropdownFilters({
    required this.departments,
    required this.provinces,
    required this.offices,
    required this.selectedDepartment,
    required this.selectedProvince,
    required this.selectedOffice,
    required this.onDepartmentChanged,
    required this.onProvinceChanged,
    required this.onOfficeChanged,
  });

  final List<String> departments;
  final List<String> provinces;
  final List<String> offices;
  final String selectedDepartment;
  final String selectedProvince;
  final String selectedOffice;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String> onProvinceChanged;
  final ValueChanged<String> onOfficeChanged;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      borderRadius: 14,
      child: Column(
        children: [
          _CompactDropdown(
            label: 'Department',
            value: selectedDepartment,
            values: departments,
            onChanged: onDepartmentChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CompactDropdown(
                  label: 'Province',
                  value: selectedProvince,
                  values: provinces,
                  onChanged: onProvinceChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactDropdown(
                  label: 'Office',
                  value: selectedOffice,
                  values: offices,
                  onChanged: onOfficeChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  const _CompactDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: values.contains(value)
          ? value
          : _SupervisorAttendanceReportsScreenState._allFilterValue,
      items: values
          .map(
            (String item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: (String? selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
      style: PulseClockTextStyles.cardSubtitle.copyWith(
        color: PulseClockColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: PulseClockColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          borderSide: const BorderSide(color: PulseClockColors.actionBlue),
        ),
      ),
    );
  }
}

class _ReportsSearchField extends StatelessWidget {
  const _ReportsSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: PulseClockTextStyles.cardSubtitle.copyWith(
        color: PulseClockColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Search employee, ID, office, status',
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

class _ReportSummaryGrid extends StatelessWidget {
  const _ReportSummaryGrid({required this.summary});

  final _ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ReportMetricCard(
                label: 'Employees',
                value: summary.employees.toString(),
                color: PulseClockColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ReportMetricCard(
                label: 'Completed',
                value: summary.completed.toString(),
                color: PulseClockColors.statusOnDutyAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ReportMetricCard(
                label: 'Absent',
                value: summary.absent.toString(),
                color: PulseClockColors.statusMissedAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ReportMetricCard(
                label: 'On Leave',
                value: summary.onLeave.toString(),
                color: PulseClockColors.statusLeaveAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ReportMetricCard(
                label: 'Exceptions',
                value: summary.locationExceptions.toString(),
                color: PulseClockColors.statusPendingAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ReportMetricCard(
                label: 'Hours',
                value: durationLabel(summary.workedDuration),
                color: PulseClockColors.actionBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PulseClockTextStyles.summaryValue.copyWith(
              color: color,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRecordCard extends StatelessWidget {
  const _ReportRecordCard({required this.record});

  final SupervisorAttendanceEmployeeRecord record;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(record.status);
    final bool isNonWorkingDay =
        record.status == SupervisorAttendanceStatus.nonWorkingDay;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      borderRadius: 14,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 62,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.employeeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PulseClockTextStyles.cardSubtitle.copyWith(
                          color: PulseClockColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _ReportStatusPill(
                      label: record.status.label,
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${dateLabel(record.date)} | ${record.employeeId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isNonWorkingDay
                      ? 'No scheduled workday'
                      : 'In ${record.clockInLabel} | Out ${record.clockOutLabel} | ${record.workHoursLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isNonWorkingDay
                      ? 'Weekend / non-working day'
                      : record.officeDisplayName ??
                            record.department ??
                            'No office',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    fontSize: 11,
                    color: record.hasLocationException
                        ? PulseClockColors.statusPendingAccent
                        : PulseClockColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportStatusPill extends StatelessWidget {
  const _ReportStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: PulseClockTextStyles.cardSubtitle.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReportPaginationControls extends StatelessWidget {
  const _ReportPaginationControls({
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 14,
      child: Row(
        children: [
          Text(
            'Page ${page + 1} of $pageCount',
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton(onPressed: onPrevious, child: const Text('Previous')),
          const SizedBox(width: 6),
          TextButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}

class _EmptyReportsCard extends StatelessWidget {
  const _EmptyReportsCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: PulseClockColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No records match the selected report filters.',
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

class _ReportSummary {
  const _ReportSummary({
    required this.employees,
    required this.completed,
    required this.absent,
    required this.onLeave,
    required this.locationExceptions,
    required this.workedDuration,
  });

  final int employees;
  final int completed;
  final int absent;
  final int onLeave;
  final int locationExceptions;
  final Duration workedDuration;

  factory _ReportSummary.fromRecords(
    List<SupervisorAttendanceEmployeeRecord> records,
  ) {
    return _ReportSummary(
      employees: records
          .map((SupervisorAttendanceEmployeeRecord record) => record.employeeId)
          .toSet()
          .length,
      completed: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) =>
                record.status == SupervisorAttendanceStatus.completed,
          )
          .length,
      absent: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) =>
                record.status == SupervisorAttendanceStatus.absent,
          )
          .length,
      onLeave: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) =>
                record.status == SupervisorAttendanceStatus.onLeave,
          )
          .length,
      locationExceptions: records
          .where(
            (SupervisorAttendanceEmployeeRecord record) =>
                record.hasLocationException,
          )
          .length,
      workedDuration: records.fold<Duration>(
        Duration.zero,
        (Duration total, SupervisorAttendanceEmployeeRecord record) =>
            total + (record.workedDuration ?? Duration.zero),
      ),
    );
  }
}

DateTimeRange _defaultRangeFor(_ReportDateRangeFilter filter) {
  final DateTime today = _dateOnly(DateTime.now());
  switch (filter) {
    case _ReportDateRangeFilter.today:
      return DateTimeRange(start: today, end: today);
    case _ReportDateRangeFilter.yesterday:
      final DateTime yesterday = today.subtract(const Duration(days: 1));
      return DateTimeRange(start: yesterday, end: yesterday);
    case _ReportDateRangeFilter.thisWeek:
      final DateTime start = today.subtract(Duration(days: today.weekday - 1));
      return DateTimeRange(start: start, end: today);
    case _ReportDateRangeFilter.lastWeek:
      final DateTime thisWeekStart = today.subtract(
        Duration(days: today.weekday - 1),
      );
      final DateTime end = thisWeekStart.subtract(const Duration(days: 1));
      final DateTime start = end.subtract(const Duration(days: 6));
      return DateTimeRange(start: start, end: end);
    case _ReportDateRangeFilter.thisMonth:
      return DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      );
    case _ReportDateRangeFilter.lastMonth:
      final DateTime start = DateTime(today.year, today.month - 1);
      final DateTime end = DateTime(today.year, today.month, 0);
      return DateTimeRange(start: start, end: end);
    case _ReportDateRangeFilter.custom:
      return DateTimeRange(start: today, end: today);
  }
}

List<String> _dropdownValues(Iterable<String?>? values) {
  final List<String> cleanedValues =
      values
          ?.map((String? value) => value?.trim())
          .whereType<String>()
          .where((String value) => value.isNotEmpty)
          .toSet()
          .toList() ??
      <String>[];
  cleanedValues.sort();
  return <String>[
    _SupervisorAttendanceReportsScreenState._allFilterValue,
    ...cleanedValues,
  ];
}

String _dateRangeLabel(DateTimeRange range) {
  if (_dateOnly(range.start) == _dateOnly(range.end)) {
    return dateLabel(range.start);
  }
  return '${dateLabel(range.start)} - ${dateLabel(range.end)}';
}

String _csvForRecords(List<SupervisorAttendanceEmployeeRecord> records) {
  final List<List<String>> rows = <List<String>>[
    <String>[
      'Date',
      'Employee Name',
      'Employee ID',
      'Department',
      'Status',
      'Clock In',
      'Clock Out',
      'Work Hours',
      'Office',
      'Province',
      'Location Exception',
      'Clock In Coordinates',
      'Clock Out Coordinates',
    ],
    for (final SupervisorAttendanceEmployeeRecord record in records)
      <String>[
        dateLabel(record.date),
        record.employeeName,
        record.employeeId,
        record.department ?? '',
        record.status.label,
        record.clockInLabel,
        record.clockOutLabel,
        record.workHoursLabel,
        record.officeDisplayName ?? '',
        record.officeProvince ?? '',
        record.hasLocationException ? 'Yes' : 'No',
        record.clockInLocation?.coordinates ?? '',
        record.clockOutLocation?.coordinates ?? '',
      ],
  ];

  return rows.map((List<String> row) => row.map(_csvCell).join(',')).join('\n');
}

String _csvCell(String value) {
  final String escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

Color _statusColor(SupervisorAttendanceStatus status) {
  switch (status) {
    case SupervisorAttendanceStatus.noClockIn:
    case SupervisorAttendanceStatus.nonWorkingDay:
      return PulseClockColors.statusOffDutyAccent;
    case SupervisorAttendanceStatus.onDuty:
    case SupervisorAttendanceStatus.completed:
      return PulseClockColors.statusOnDutyAccent;
    case SupervisorAttendanceStatus.missedPunch:
    case SupervisorAttendanceStatus.absent:
      return PulseClockColors.statusMissedAccent;
    case SupervisorAttendanceStatus.correctionPending:
    case SupervisorAttendanceStatus.leavePending:
      return PulseClockColors.statusPendingAccent;
    case SupervisorAttendanceStatus.onLeave:
      return PulseClockColors.statusLeaveAccent;
  }
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}
