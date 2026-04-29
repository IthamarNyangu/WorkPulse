import 'package:flutter/material.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/features/attendance/history/attendance_history_detail_screen.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
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
  List<AttendanceRecord> _records = <AttendanceRecord>[];
  bool _isLoading = true;
  String? _loadError;

  bool get _usesBackend => SupabaseBootstrap.isInitialized;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _store.addListener(_onStoreChanged);
    _loadRecords();
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

    if (_usesBackend) {
      _loadRecords();
      return;
    }

    setState(() {
      _records = _store.historyAttendanceRecords;
    });
  }

  Future<void> _loadRecords() async {
    if (!_usesBackend) {
      if (!mounted) {
        return;
      }
      setState(() {
        _records = _store.historyAttendanceRecords;
        _isLoading = false;
        _loadError = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final List<AttendanceRecord> records = await AttendanceService()
          .fetchHistoryRecords();
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _records = <AttendanceRecord>[];
        _isLoading = false;
        _loadError = error.toString();
      });
    }
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
          records: _records,
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
            child: _isLoading
                ? const _HistoryLoadingState()
                : _loadError != null
                ? _HistoryErrorState(
                    message: _loadError!,
                    onRetry: _loadRecords,
                  )
                : filteredRecords.isEmpty
                ? const _HistoryEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadRecords,
                    child: ListView.separated(
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
          ),
        ],
      ),
    );
  }
}

class _HistoryLoadingState extends StatelessWidget {
  const _HistoryLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          PulseClockColors.surface,
        ),
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

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB42318),
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load attendance history.',
              style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: PulseClockTextStyles.cardSubtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
