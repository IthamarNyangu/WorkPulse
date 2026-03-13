import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/screens/attendance_history_detail_screen.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  HistoryDateRangeFilter _selectedDateRange = HistoryDateRangeFilter.thisWeek;
  HistoryStatusFilter _selectedStatus = HistoryStatusFilter.all;
  final WorkPulseMockStore _store = WorkPulseMockStore.instance;
  late final DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _openRecordDetails(AttendanceRecord record) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return AttendanceHistoryDetailScreen(recordId: record.id);
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<AttendanceRecord> filteredRecords =
        filterAttendanceHistoryRecords(
          records: _store.attendanceRecords,
          dateRange: _selectedDateRange,
          statusFilter: _selectedStatus,
          now: _now,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PulseClockDimensions.horizontalPadding,
        PulseClockDimensions.topPadding,
        PulseClockDimensions.horizontalPadding,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance History',
            style: PulseClockTextStyles.headerTitle,
          ),
          const SizedBox(height: 6),
          const Text(
            'Filter by date range and status.',
            style: PulseClockTextStyles.headerSubtitle,
          ),
          const SizedBox(height: 14),
          Text(
            'Date Range',
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.onBackgroundPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          HistoryFilterChipBar<HistoryDateRangeFilter>(
            items: HistoryDateRangeFilter.values,
            selectedValue: _selectedDateRange,
            labelBuilder: (HistoryDateRangeFilter filter) => filter.label,
            onSelected: (HistoryDateRangeFilter filter) {
              if (filter == _selectedDateRange) {
                return;
              }
              setState(() {
                _selectedDateRange = filter;
              });
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Status',
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.onBackgroundPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          HistoryFilterChipBar<HistoryStatusFilter>(
            items: HistoryStatusFilter.values,
            selectedValue: _selectedStatus,
            labelBuilder: (HistoryStatusFilter filter) => filter.label,
            onSelected: (HistoryStatusFilter filter) {
              if (filter == _selectedStatus) {
                return;
              }
              setState(() {
                _selectedStatus = filter;
              });
            },
          ),
          const SizedBox(height: 14),
          Expanded(
            child: filteredRecords.isEmpty
                ? const _HistoryEmptyState()
                : ListView.separated(
                    itemCount: filteredRecords.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final AttendanceRecord record = filteredRecords[index];
                      return HistoryRecordCard(
                        record: record,
                        onTap: () => _openRecordDetails(record),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SurfaceCard(
        child: Row(
          children: [
            const Icon(
              Icons.history_toggle_off_rounded,
              color: PulseClockColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No attendance records found for this filter.',
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
