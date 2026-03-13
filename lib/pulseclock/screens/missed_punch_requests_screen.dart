import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/screens/correction_request_form_screen.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class MissedPunchRequestsScreen extends StatefulWidget {
  const MissedPunchRequestsScreen({super.key});

  @override
  State<MissedPunchRequestsScreen> createState() =>
      _MissedPunchRequestsScreenState();
}

class _MissedPunchRequestsScreenState extends State<MissedPunchRequestsScreen> {
  static const int _pageSize = 4;

  final WorkPulseMockStore _store = WorkPulseMockStore.instance;
  final Set<String> _expandedRecordIds = <String>{};
  int _currentPage = 0;

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
    setState(() {
      final int totalPages = _totalPages;
      if (_currentPage >= totalPages) {
        _currentPage = totalPages - 1;
      }
      if (_currentPage < 0) {
        _currentPage = 0;
      }
    });
  }

  List<AttendanceRecord> get _missedPunchRecords {
    return _store.missedPunchRecords;
  }

  int get _totalPages {
    final int count = _missedPunchRecords.length;
    if (count == 0) {
      return 1;
    }
    return ((count - 1) ~/ _pageSize) + 1;
  }

  List<AttendanceRecord> _recordsOnCurrentPage() {
    final List<AttendanceRecord> all = _missedPunchRecords;
    if (all.isEmpty) {
      return const <AttendanceRecord>[];
    }

    final int start = _currentPage * _pageSize;
    if (start >= all.length) {
      return const <AttendanceRecord>[];
    }

    final int end = (start + _pageSize) > all.length
        ? all.length
        : start + _pageSize;
    return all.sublist(start, end);
  }

  Future<void> _openCorrectionForm(AttendanceRecord record) async {
    final CorrectionType initialType = record.clockOutTime == '--'
        ? CorrectionType.clockOut
        : CorrectionType.both;

    final bool? submitted = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return CorrectionRequestFormScreen(
                attendanceRecordId: record.id,
                affectedDate: record.date,
                issueSummary: _issueSummaryFor(record),
                initialCorrectionType: initialType,
              );
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted || submitted != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correction request submitted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<AttendanceRecord> currentPageRecords = _recordsOnCurrentPage();
    final bool hasRecords = _missedPunchRecords.isNotEmpty;

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Missed Punches'),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PulseClockDimensions.horizontalPadding,
              PulseClockDimensions.topPadding,
              PulseClockDimensions.horizontalPadding,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missed Punch Records',
                  style: PulseClockTextStyles.headerSubtitle.copyWith(
                    color: PulseClockColors.onBackgroundPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: hasRecords
                      ? ListView.separated(
                          itemCount: currentPageRecords.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final AttendanceRecord record =
                                currentPageRecords[index];
                            final bool isExpanded = _expandedRecordIds.contains(
                              record.id,
                            );

                            return _MissedPunchCard(
                              key: ValueKey<String>('missed_${record.id}'),
                              record: record,
                              isExpanded: isExpanded,
                              onExpansionChanged: (bool expanded) {
                                setState(() {
                                  if (expanded) {
                                    _expandedRecordIds.add(record.id);
                                  } else {
                                    _expandedRecordIds.remove(record.id);
                                  }
                                });
                              },
                              onRequestCorrection: () =>
                                  _openCorrectionForm(record),
                            );
                          },
                        )
                      : const _NoMissedPunchState(),
                ),
                if (hasRecords && _totalPages > 1) ...<Widget>[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _currentPage > 0
                              ? () {
                                  setState(() {
                                    _currentPage -= 1;
                                  });
                                }
                              : null,
                          child: const Text('Previous'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Page ${_currentPage + 1} of $_totalPages',
                        style: PulseClockTextStyles.cardSubtitle.copyWith(
                          color: PulseClockColors.onBackgroundPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: (_currentPage + 1) < _totalPages
                              ? () {
                                  setState(() {
                                    _currentPage += 1;
                                  });
                                }
                              : null,
                          child: const Text('Next'),
                        ),
                      ),
                    ],
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

class _MissedPunchCard extends StatelessWidget {
  const _MissedPunchCard({
    super.key,
    required this.record,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onRequestCorrection,
  });

  final AttendanceRecord record;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final VoidCallback onRequestCorrection;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      borderRadius: 14,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailInfoRow(
                label: 'Affected Date',
                value: dateLabel(record.date),
              ),
              const SizedBox(height: 6),
              DetailInfoRow(
                label: 'Correction Type',
                value: _missedClockTypeLabel(record),
              ),
            ],
          ),
          children: [
            const Divider(color: PulseClockColors.cardBorder),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Fill correction details in the form.',
                textAlign: TextAlign.left,
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRequestCorrection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PulseClockColors.actionBlue,
                  foregroundColor: PulseClockColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: PulseClockTextStyles.contextAction.copyWith(
                    color: PulseClockColors.surface,
                    fontSize: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      PulseClockDimensions.cardRadius,
                    ),
                  ),
                ),
                child: const Text('Continue to Correction Form'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMissedPunchState extends StatelessWidget {
  const _NoMissedPunchState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SurfaceCard(
        child: Row(
          children: [
            const Icon(
              Icons.task_alt_rounded,
              color: PulseClockColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No missed punches available.',
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

CorrectionType _suggestedCorrectionType(AttendanceRecord record) {
  if (record.clockOutTime == '--') {
    return CorrectionType.clockOut;
  }
  if (record.clockInTime == '--') {
    return CorrectionType.clockIn;
  }
  return CorrectionType.both;
}

String _missedClockTypeLabel(AttendanceRecord record) {
  final CorrectionType type = _suggestedCorrectionType(record);
  switch (type) {
    case CorrectionType.clockIn:
      return 'Missed Clock In';
    case CorrectionType.clockOut:
      return 'Missed Clock Out';
    case CorrectionType.both:
      return 'Missed Clock In & Clock Out';
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
