import 'package:flutter/material.dart';
import 'package:pulseclock/features/corrections/correction_form_screen.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class CorrectionDetailsScreen extends StatefulWidget {
  const CorrectionDetailsScreen({super.key, this.initialRequestId});

  final String? initialRequestId;

  @override
  State<CorrectionDetailsScreen> createState() => _CorrectionDetailsScreenState();
}

class _CorrectionDetailsScreenState extends State<CorrectionDetailsScreen> {
  static const int _pageSize = 4;

  final WorkPulseMockStore _store = WorkPulseMockStore.instance;
  final Set<String> _expandedRequestIds = <String>{};
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);

    if (widget.initialRequestId != null) {
      _expandedRequestIds.add(widget.initialRequestId!);
      _currentPage = _pageForRequest(widget.initialRequestId!);
    }
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

  Future<void> _openEditRequestForm(CorrectionRequest request) async {
    final AttendanceRecord? record = _store.attendanceRecordById(
      request.attendanceRecordId,
    );
    if (record == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance record no longer exists.')),
      );
      return;
    }

    final bool? updated = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return CorrectionFormScreen(
                attendanceRecordId: record.id,
                affectedDate: request.affectedDate,
                issueSummary: request.issueSummary,
                initialCorrectionType: request.correctionType,
                existingRequestId: request.id,
                initialCorrectedClockInTime: request.correctedClockInTime,
                initialCorrectedClockOutTime: request.correctedClockOutTime,
                initialReason: request.reason,
              );
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted || updated != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correction request updated.')),
    );
  }

  List<CorrectionRequest> get _pendingRequests {
    return _store.pendingCorrectionRequests;
  }

  int get _totalPages {
    final int count = _pendingRequests.length;
    if (count == 0) {
      return 1;
    }
    return ((count - 1) ~/ _pageSize) + 1;
  }

  int _pageForRequest(String requestId) {
    final List<CorrectionRequest> requests = _pendingRequests;
    final int index = requests.indexWhere(
      (CorrectionRequest request) => request.id == requestId,
    );
    if (index < 0) {
      return 0;
    }
    return index ~/ _pageSize;
  }

  List<CorrectionRequest> _requestsOnCurrentPage() {
    final List<CorrectionRequest> all = _pendingRequests;
    if (all.isEmpty) {
      return const <CorrectionRequest>[];
    }

    final int start = _currentPage * _pageSize;
    if (start >= all.length) {
      return const <CorrectionRequest>[];
    }

    final int end = (start + _pageSize) > all.length
        ? all.length
        : start + _pageSize;
    return all.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final List<CorrectionRequest> currentPageRequests = _requestsOnCurrentPage();
    final bool hasRequests = _pendingRequests.isNotEmpty;

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Correction Requests'),
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
                  'Pending Requests',
                  style: PulseClockTextStyles.headerSubtitle.copyWith(
                    color: PulseClockColors.onBackgroundPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: hasRequests
                      ? ListView.separated(
                          itemCount: currentPageRequests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final CorrectionRequest request =
                                currentPageRequests[index];
                            final bool isExpanded = _expandedRequestIds.contains(
                              request.id,
                            );

                            return _PendingCorrectionCard(
                              key: ValueKey<String>('pending_${request.id}'),
                              request: request,
                              isExpanded: isExpanded,
                              onEditRequest: () => _openEditRequestForm(request),
                              onExpansionChanged: (bool expanded) {
                                setState(() {
                                  if (expanded) {
                                    _expandedRequestIds.add(request.id);
                                  } else {
                                    _expandedRequestIds.remove(request.id);
                                  }
                                });
                              },
                            );
                          },
                        )
                      : const _NoPendingRequestState(),
                ),
                if (hasRequests && _totalPages > 1) ...<Widget>[
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

class _PendingCorrectionCard extends StatelessWidget {
  const _PendingCorrectionCard({
    super.key,
    required this.request,
    required this.isExpanded,
    required this.onEditRequest,
    required this.onExpansionChanged,
  });

  final CorrectionRequest request;
  final bool isExpanded;
  final VoidCallback onEditRequest;
  final ValueChanged<bool> onExpansionChanged;

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
                value: dateLabel(request.affectedDate),
              ),
              const SizedBox(height: 6),
              DetailInfoRow(label: 'Status', value: request.status.label),
              const SizedBox(height: 6),
              DetailInfoRow(
                label: 'Correction Type',
                value: request.correctionType.label,
              ),
            ],
          ),
          children: [
            const Divider(color: PulseClockColors.cardBorder),
            const SizedBox(height: 10),
            DetailInfoRow(
              label: 'Corrected Clock In',
              value: request.correctedClockInTime ?? '--',
            ),
            const SizedBox(height: 8),
            DetailInfoRow(
              label: 'Corrected Clock Out',
              value: request.correctedClockOutTime ?? '--',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Issue Summary',
                textAlign: TextAlign.left,
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                request.issueSummary,
                textAlign: TextAlign.left,
                style: PulseClockTextStyles.cardSubtitle,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Reason',
                textAlign: TextAlign.left,
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                request.reason,
                textAlign: TextAlign.left,
                style: PulseClockTextStyles.cardSubtitle,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onEditRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PulseClockColors.actionBlue,
                  foregroundColor: PulseClockColors.surface,
                  textStyle: PulseClockTextStyles.contextAction.copyWith(
                    color: PulseClockColors.surface,
                    fontSize: 15,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      PulseClockDimensions.cardRadius,
                    ),
                  ),
                ),
                child: const Text('Edit Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPendingRequestState extends StatelessWidget {
  const _NoPendingRequestState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SurfaceCard(
        child: Row(
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              color: PulseClockColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No pending correction requests available.',
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
