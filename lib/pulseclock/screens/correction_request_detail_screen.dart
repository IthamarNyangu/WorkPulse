import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class CorrectionRequestDetailScreen extends StatefulWidget {
  const CorrectionRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<CorrectionRequestDetailScreen> createState() =>
      _CorrectionRequestDetailScreenState();
}

class _CorrectionRequestDetailScreenState
    extends State<CorrectionRequestDetailScreen> {
  final WorkPulseMockStore _store = WorkPulseMockStore.instance;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final CorrectionRequest? request = _store.correctionRequestById(
      widget.requestId,
    );

    if (request == null) {
      return Scaffold(
        backgroundColor: PulseClockColors.appBackground,
        appBar: AppBar(
          title: const Text('Correction Request'),
          backgroundColor: PulseClockColors.surface,
          foregroundColor: PulseClockColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This correction request is no longer available.',
              style: PulseClockTextStyles.cardSubtitle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Correction Request'),
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
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pending Request',
                          style: PulseClockTextStyles.cardTitle.copyWith(
                            fontSize: 22,
                          ),
                        ),
                      ),
                      HistoryStatusBadge(
                        status: AttendanceRecordStatus.correctionPending,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: PulseClockColors.cardBorder),
                  const SizedBox(height: 12),
                  DetailInfoRow(
                    label: 'Affected Date',
                    value: dateLabel(request.affectedDate),
                  ),
                  const SizedBox(height: 10),
                  DetailInfoRow(label: 'Status', value: request.status.label),
                  const SizedBox(height: 10),
                  DetailInfoRow(
                    label: 'Correction Type',
                    value: request.correctionType.label,
                  ),
                  const SizedBox(height: 10),
                  DetailInfoRow(
                    label: 'Corrected Clock In',
                    value: request.correctedClockInTime ?? '--',
                  ),
                  const SizedBox(height: 10),
                  DetailInfoRow(
                    label: 'Corrected Clock Out',
                    value: request.correctedClockOutTime ?? '--',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Issue Summary',
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.issueSummary,
                    style: PulseClockTextStyles.cardSubtitle,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reason',
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(request.reason, style: PulseClockTextStyles.cardSubtitle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
