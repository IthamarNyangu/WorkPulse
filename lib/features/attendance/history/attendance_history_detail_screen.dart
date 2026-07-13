import 'package:flutter/material.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/features/corrections/correction_form_screen.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class AttendanceHistoryDetailScreen extends StatefulWidget {
  const AttendanceHistoryDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  State<AttendanceHistoryDetailScreen> createState() =>
      _AttendanceHistoryDetailScreenState();
}

class _AttendanceHistoryDetailScreenState
    extends State<AttendanceHistoryDetailScreen> {
  final WorkPulseMockStore _store = WorkPulseMockStore.instance;
  AttendanceRecord? _record;
  bool _isLoading = true;

  bool get _usesBackend => SupabaseBootstrap.isInitialized;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _loadRecord();
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
    _loadRecord();
  }

  Future<void> _loadRecord() async {
    if (!_usesBackend) {
      if (!mounted) {
        return;
      }
      setState(() {
        _record = _store.attendanceRecordById(widget.recordId);
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final AttendanceRecord? record = await AttendanceService()
          .fetchHistoryRecordById(widget.recordId);
      if (!mounted) {
        return;
      }
      setState(() {
        _record = record;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _record = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _openCorrectionForm(AttendanceRecord record) async {
    final CorrectionType? initialType = record.clockOutTime == '--'
        ? CorrectionType.clockOut
        : null;

    final bool? submitted = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return CorrectionFormScreen(
                attendanceRecordId: record.id,
                affectedDate: record.date,
                issueSummary: _issueSummaryFor(record),
                initialCorrectionType: initialType,
                sourceRecord: record,
              );
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted || submitted != true) {
      return;
    }

    await _loadRecord();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correction request submitted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: PulseClockColors.appBackground,
        appBar: AppBar(
          title: const Text('Attendance Details'),
          backgroundColor: PulseClockColors.surface,
          foregroundColor: PulseClockColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(PulseClockColors.surface),
          ),
        ),
      );
    }

    final AttendanceRecord? record = _record;

    if (record == null) {
      return Scaffold(
        backgroundColor: PulseClockColors.appBackground,
        appBar: AppBar(
          title: const Text('Attendance Details'),
          backgroundColor: PulseClockColors.surface,
          foregroundColor: PulseClockColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Attendance record is no longer available.',
              style: PulseClockTextStyles.cardSubtitle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final bool showCorrectionAction =
        record.status == AttendanceRecordStatus.missedPunch;

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Attendance Details'),
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
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
              PulseClockDimensions.topPadding,
              PulseClockDimensions.horizontalPadding,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateLabel(record.date),
                              style: PulseClockTextStyles.cardTitle.copyWith(
                                fontSize: 22,
                              ),
                            ),
                          ),
                          HistoryStatusBadge(status: record.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: PulseClockColors.cardBorder),
                      const SizedBox(height: 12),
                      DetailInfoRow(label: 'Record ID', value: record.id),
                      const SizedBox(height: 10),
                      DetailInfoRow(
                        label: 'Day',
                        value: weekdayName(record.date),
                      ),
                      const SizedBox(height: 10),
                      DetailInfoRow(
                        label: 'Clock In',
                        value: record.clockInTime,
                      ),
                      const SizedBox(height: 10),
                      DetailInfoRow(
                        label: 'Clock Out',
                        value: record.clockOutTime,
                      ),
                      const SizedBox(height: 10),
                      DetailInfoRow(
                        label: 'Work Hours',
                        value: record.workHours,
                      ),
                      if (record.note != null) ...<Widget>[
                        const SizedBox(height: 12),
                        const Divider(color: PulseClockColors.cardBorder),
                        const SizedBox(height: 12),
                        Text(
                          'Notes',
                          style: PulseClockTextStyles.cardSubtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.note!,
                          style: PulseClockTextStyles.cardSubtitle,
                        ),
                      ],
                    ],
                  ),
                ),
                if (showCorrectionAction) ...<Widget>[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openCorrectionForm(record),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Request Correction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PulseClockColors.actionBlue,
                        foregroundColor: PulseClockColors.surface,
                        textStyle: PulseClockTextStyles.contextAction.copyWith(
                          color: PulseClockColors.surface,
                          fontSize: 17,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PulseClockDimensions.cardRadius,
                          ),
                        ),
                      ),
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
}

String _issueSummaryFor(AttendanceRecord record) {
  if (record.note != null && record.note!.trim().isNotEmpty) {
    return record.note!;
  }
  if (record.clockOutTime == '--') {
    return 'Missing Clock Out for ${dateLabel(record.date)}';
  }
  if (record.clockInTime == '--') {
    return 'Missing Clock In for ${dateLabel(record.date)}';
  }
  return 'Attendance correction requested for ${dateLabel(record.date)}';
}
