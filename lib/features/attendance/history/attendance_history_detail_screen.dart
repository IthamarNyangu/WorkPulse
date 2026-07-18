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
                if (record.clockInLocation != null ||
                    record.clockOutLocation != null) ...<Widget>[
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location Details',
                          style: PulseClockTextStyles.cardTitle.copyWith(
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (record.clockInLocation != null)
                          _AttendanceLocationBlock(
                            title: 'Clock In Location',
                            snapshot: record.clockInLocation!,
                          ),
                        if (record.clockInLocation != null &&
                            record.clockOutLocation != null) ...<Widget>[
                          const SizedBox(height: 12),
                          const Divider(color: PulseClockColors.cardBorder),
                          const SizedBox(height: 12),
                        ],
                        if (record.clockOutLocation != null)
                          _AttendanceLocationBlock(
                            title: 'Clock Out Location',
                            snapshot: record.clockOutLocation!,
                          ),
                      ],
                    ),
                  ),
                ],
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

class _AttendanceLocationBlock extends StatelessWidget {
  const _AttendanceLocationBlock({required this.title, required this.snapshot});

  final String title;
  final ClockLocationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _locationStatusColor(snapshot.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: PulseClockTextStyles.cardSubtitle.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _LocationDetailLine(label: 'Coordinates', value: snapshot.coordinates),
        const SizedBox(height: 6),
        _LocationDetailLine(
          label: 'Accuracy',
          value:
              '${snapshot.accuracyMeters.toStringAsFixed(1)} m (${snapshot.accuracyQualityLabel})',
        ),
        if (snapshot.officeDisplayName != null) ...<Widget>[
          const SizedBox(height: 6),
          _LocationDetailLine(
            label: snapshot.isInsideGeofence
                ? 'Verified Office'
                : 'Nearest Office',
            value: snapshot.officeDisplayName!,
          ),
        ],
        if (snapshot.distanceMeters != null) ...<Widget>[
          const SizedBox(height: 6),
          _LocationDetailLine(
            label: 'Distance',
            value: _metersLabel(snapshot.distanceMeters!),
          ),
        ],
        if (snapshot.geofenceRadiusMeters != null) ...<Widget>[
          const SizedBox(height: 6),
          _LocationDetailLine(
            label: 'Allowed Radius',
            value: _metersLabel(snapshot.geofenceRadiusMeters!),
          ),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            snapshot.geofenceLabel,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationDetailLine extends StatelessWidget {
  const _LocationDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(label, style: PulseClockTextStyles.cardSubtitle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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

String _metersLabel(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
  return '${meters.toStringAsFixed(0)} m';
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
