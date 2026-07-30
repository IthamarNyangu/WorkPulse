import 'package:flutter/material.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/features/corrections/correction_form_screen.dart';
import 'package:pulseclock/features/corrections/data/correction_service.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

enum _CorrectionTab { needAction, submitted }

class CorrectionListScreen extends StatefulWidget {
  const CorrectionListScreen({super.key});

  @override
  State<CorrectionListScreen> createState() => _CorrectionListScreenState();
}

class _CorrectionListScreenState extends State<CorrectionListScreen> {
  static const int _pageSize = 4;

  final WorkPulseMockStore _store = WorkPulseMockStore.instance;
  final Set<String> _expandedRecordIds = <String>{};
  final Set<String> _expandedRequestIds = <String>{};

  List<AttendanceRecord> _recordsNeedingAction = <AttendanceRecord>[];
  List<CorrectionRequest> _submittedRequests = <CorrectionRequest>[];
  int _needActionPage = 0;
  int _submittedPage = 0;
  bool _isLoading = true;
  String? _loadError;
  _CorrectionTab _selectedTab = _CorrectionTab.needAction;

  bool get _usesBackend => SupabaseBootstrap.isInitialized;

  int get _needActionTotalPages => _pageCount(_recordsNeedingAction.length);
  int get _submittedTotalPages => _pageCount(_submittedRequests.length);

  int get _selectedPage => _selectedTab == _CorrectionTab.needAction
      ? _needActionPage
      : _submittedPage;

  int get _selectedTotalPages => _selectedTab == _CorrectionTab.needAction
      ? _needActionTotalPages
      : _submittedTotalPages;

  bool get _selectedTabHasItems => _selectedTab == _CorrectionTab.needAction
      ? _recordsNeedingAction.isNotEmpty
      : _submittedRequests.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _loadCorrectionOverview();
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
      _loadCorrectionOverview();
      return;
    }

    setState(() {
      _recordsNeedingAction = _store.missedPunchRecords;
      _submittedRequests = _store.pendingCorrectionRequests;
      _clampPages();
    });
  }

  Future<void> _loadCorrectionOverview() async {
    if (!_usesBackend) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recordsNeedingAction = _store.missedPunchRecords;
        _submittedRequests = _store.pendingCorrectionRequests;
        _isLoading = false;
        _loadError = null;
        _clampPages();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final CorrectionService service = CorrectionService();
      final List<AttendanceRecord> records = await service
          .fetchMissedPunchRecords();
      final List<CorrectionRequest> requests = await service
          .fetchPendingCorrectionRequests();
      if (!mounted) {
        return;
      }
      setState(() {
        _recordsNeedingAction = records;
        _submittedRequests = requests;
        _isLoading = false;
        _needActionPage = 0;
        _submittedPage = 0;
        _clampPages();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recordsNeedingAction = <AttendanceRecord>[];
        _submittedRequests = <CorrectionRequest>[];
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  int _pageCount(int count) {
    if (count == 0) {
      return 1;
    }
    return ((count - 1) ~/ _pageSize) + 1;
  }

  void _clampPages() {
    if (_needActionPage >= _needActionTotalPages) {
      _needActionPage = _needActionTotalPages - 1;
    }
    if (_submittedPage >= _submittedTotalPages) {
      _submittedPage = _submittedTotalPages - 1;
    }
    if (_needActionPage < 0) {
      _needActionPage = 0;
    }
    if (_submittedPage < 0) {
      _submittedPage = 0;
    }
  }

  List<T> _itemsOnPage<T>(List<T> items, int page) {
    if (items.isEmpty) {
      return <T>[];
    }

    final int start = page * _pageSize;
    if (start >= items.length) {
      return <T>[];
    }

    final int end = (start + _pageSize) > items.length
        ? items.length
        : start + _pageSize;
    return items.sublist(start, end);
  }

  Future<void> _openCorrectionForm(AttendanceRecord record) async {
    final CorrectionType initialType = _suggestedCorrectionType(record);

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

    await _loadCorrectionOverview();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTab = _CorrectionTab.submitted;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correction request submitted.')),
    );
  }

  Future<void> _openEditRequestForm(CorrectionRequest request) async {
    AttendanceRecord? record;
    if (_usesBackend) {
      if (request.attendanceRecordId.isNotEmpty) {
        try {
          record = await AttendanceService().fetchHistoryRecordById(
            request.attendanceRecordId,
          );
        } catch (_) {
          record = null;
        }
      }
    } else {
      record = _store.attendanceRecordById(request.attendanceRecordId);
    }

    if (record == null && !_usesBackend) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance record no longer exists.')),
      );
      return;
    }

    if (!mounted) {
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
                attendanceRecordId: record?.id ?? request.attendanceRecordId,
                affectedDate: request.affectedDate,
                issueSummary: request.issueSummary,
                initialCorrectionType: request.correctionType,
                existingRequestId: request.id,
                initialCorrectedClockInTime: request.correctedClockInTime,
                initialCorrectedClockOutTime: request.correctedClockOutTime,
                initialReason: request.reason,
                sourceRecord: record,
              );
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted || updated != true) {
      return;
    }

    await _loadCorrectionOverview();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTab = _CorrectionTab.submitted;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correction request updated.')),
    );
  }

  void _previousPage() {
    setState(() {
      if (_selectedTab == _CorrectionTab.needAction) {
        _needActionPage -= 1;
      } else {
        _submittedPage -= 1;
      }
      _clampPages();
    });
  }

  void _nextPage() {
    setState(() {
      if (_selectedTab == _CorrectionTab.needAction) {
        _needActionPage += 1;
      } else {
        _submittedPage += 1;
      }
      _clampPages();
    });
  }

  Widget _buildCurrentTabContent() {
    if (_isLoading) {
      return const _CorrectionLoadingState();
    }

    if (_loadError != null) {
      return _CorrectionErrorState(
        message: _loadError!,
        onRetry: _loadCorrectionOverview,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCorrectionOverview,
      child: _selectedTab == _CorrectionTab.needAction
          ? _buildNeedActionList()
          : _buildSubmittedList(),
    );
  }

  Widget _buildNeedActionList() {
    final List<AttendanceRecord> records = _itemsOnPage<AttendanceRecord>(
      _recordsNeedingAction,
      _needActionPage,
    );

    if (_recordsNeedingAction.isEmpty) {
      return const _ScrollableEmptyState(child: _NoNeedActionState());
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final AttendanceRecord record = records[index];
        final bool isExpanded = _expandedRecordIds.contains(record.id);

        return _NeedsActionRecordCard(
          key: ValueKey<String>('needs_action_${record.id}'),
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
          onRequestCorrection: () => _openCorrectionForm(record),
        );
      },
    );
  }

  Widget _buildSubmittedList() {
    final List<CorrectionRequest> requests = _itemsOnPage<CorrectionRequest>(
      _submittedRequests,
      _submittedPage,
    );

    if (_submittedRequests.isEmpty) {
      return const _ScrollableEmptyState(child: _NoSubmittedRequestState());
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final CorrectionRequest request = requests[index];
        final bool isExpanded = _expandedRequestIds.contains(request.id);

        return _SubmittedCorrectionCard(
          key: ValueKey<String>('submitted_${request.id}'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Attendance Corrections'),
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
                  'Attendance updates',
                  style: PulseClockTextStyles.headerSubtitle.copyWith(
                    color: PulseClockColors.onBackgroundPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _CorrectionTabSelector(
                  selectedTab: _selectedTab,
                  needActionCount: _recordsNeedingAction.length,
                  submittedCount: _submittedRequests.length,
                  onSelected: (_CorrectionTab tab) {
                    setState(() {
                      _selectedTab = tab;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildCurrentTabContent()),
                if (!_isLoading &&
                    _loadError == null &&
                    _selectedTabHasItems &&
                    _selectedTotalPages > 1) ...<Widget>[
                  const SizedBox(height: 10),
                  _CorrectionPaginationControls(
                    currentPage: _selectedPage,
                    totalPages: _selectedTotalPages,
                    onPrevious: _selectedPage > 0 ? _previousPage : null,
                    onNext: (_selectedPage + 1) < _selectedTotalPages
                        ? _nextPage
                        : null,
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

class _CorrectionTabSelector extends StatelessWidget {
  const _CorrectionTabSelector({
    required this.selectedTab,
    required this.needActionCount,
    required this.submittedCount,
    required this.onSelected,
  });

  final _CorrectionTab selectedTab;
  final int needActionCount;
  final int submittedCount;
  final ValueChanged<_CorrectionTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(5),
      color: PulseClockColors.surface,
      child: Row(
        children: [
          Expanded(
            child: _CorrectionTabButton(
              label: 'Need Action',
              count: needActionCount,
              isSelected: selectedTab == _CorrectionTab.needAction,
              onTap: () => onSelected(_CorrectionTab.needAction),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _CorrectionTabButton(
              label: 'Submitted',
              count: submittedCount,
              isSelected: selectedTab == _CorrectionTab.submitted,
              onTap: () => onSelected(_CorrectionTab.submitted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrectionTabButton extends StatelessWidget {
  const _CorrectionTabButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = isSelected
        ? PulseClockColors.surface
        : PulseClockColors.textPrimary;
    final Color countBackground = isSelected
        ? PulseClockColors.surface.withValues(alpha: 0.18)
        : PulseClockColors.statusPendingBg;

    return Material(
      color: isSelected ? PulseClockColors.actionBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PulseClockTextStyles.contextAction.copyWith(
                    color: foreground,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: countBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  child: Text(
                    count.toString(),
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      color: foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeedsActionRecordCard extends StatelessWidget {
  const _NeedsActionRecordCard({
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
              _NeedsActionSummaryRow(
                label: 'Affected Date',
                value: dateLabel(record.date),
              ),
              const SizedBox(height: 6),
              _NeedsActionSummaryRow(
                label: 'Correction Type',
                value: _missedClockTypeLabel(record),
                compactValue: true,
              ),
            ],
          ),
          children: [
            const Divider(color: PulseClockColors.cardBorder),
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
                child: const Text('Submit Correction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeedsActionSummaryRow extends StatelessWidget {
  const _NeedsActionSummaryRow({
    required this.label,
    required this.value,
    this.compactValue = false,
  });

  final String label;
  final String value;
  final bool compactValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 122,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.textPrimary,
              fontSize: compactValue ? 13 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmittedCorrectionCard extends StatelessWidget {
  const _SubmittedCorrectionCard({
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
          tilePadding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      dateLabel(request.affectedDate),
                      style: PulseClockTextStyles.cardTitle.copyWith(
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CorrectionStatusPill(label: request.status.label),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                request.correctionType.label,
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  color: PulseClockColors.actionBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                request.issueSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  color: PulseClockColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          children: [
            const Divider(color: PulseClockColors.cardBorder),
            const SizedBox(height: 10),
            DetailInfoRow(
              label: 'Corrected Clock In',
              value: _timeValue(request.correctedClockInTime),
            ),
            const SizedBox(height: 8),
            DetailInfoRow(
              label: 'Corrected Clock Out',
              value: _timeValue(request.correctedClockOutTime),
            ),
            const SizedBox(height: 12),
            _CorrectionNotePanel(
              title: 'Issue Summary',
              value: request.issueSummary,
            ),
            const SizedBox(height: 10),
            _CorrectionNotePanel(title: 'Reason', value: request.reason),
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

class _CorrectionStatusPill extends StatelessWidget {
  const _CorrectionStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PulseClockColors.statusPendingBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: PulseClockTextStyles.cardSubtitle.copyWith(
            color: PulseClockColors.statusPendingAccent,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CorrectionNotePanel extends StatelessWidget {
  const _CorrectionNotePanel({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PulseClockColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PulseClockColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                color: PulseClockColors.actionBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrectionPaginationControls extends StatelessWidget {
  const _CorrectionPaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: onPrevious,
            style: _paginationButtonStyle(),
            child: const Text('Previous'),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Page ${currentPage + 1} of $totalPages',
          style: PulseClockTextStyles.cardSubtitle.copyWith(
            color: PulseClockColors.onBackgroundPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: onNext,
            style: _paginationButtonStyle(),
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }
}

ButtonStyle _paginationButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: PulseClockColors.actionBlue,
    foregroundColor: PulseClockColors.surface,
    disabledBackgroundColor: PulseClockColors.surface.withValues(alpha: 0.54),
    disabledForegroundColor: PulseClockColors.textSecondary.withValues(
      alpha: 0.72,
    ),
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 12),
    textStyle: PulseClockTextStyles.contextAction.copyWith(
      color: PulseClockColors.surface,
      fontSize: 14,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

class _ScrollableEmptyState extends StatelessWidget {
  const _ScrollableEmptyState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [const SizedBox(height: 140), child],
    );
  }
}

class _NoNeedActionState extends StatelessWidget {
  const _NoNeedActionState();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          const Icon(
            Icons.task_alt_rounded,
            color: PulseClockColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No records currently need correction.',
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSubmittedRequestState extends StatelessWidget {
  const _NoSubmittedRequestState();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            color: PulseClockColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No submitted correction requests.',
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrectionLoadingState extends StatelessWidget {
  const _CorrectionLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(PulseClockColors.surface),
      ),
    );
  }
}

class _CorrectionErrorState extends StatelessWidget {
  const _CorrectionErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFB42318)),
            const SizedBox(height: 12),
            Text(
              'Unable to load correction requests.',
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
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

CorrectionType _suggestedCorrectionType(AttendanceRecord record) {
  final bool missingClockIn = record.clockInTime == '--';
  final bool missingClockOut = record.clockOutTime == '--';
  if (record.status == AttendanceRecordStatus.absent ||
      (missingClockIn && missingClockOut)) {
    return CorrectionType.both;
  }
  if (missingClockOut) {
    return CorrectionType.clockOut;
  }
  if (missingClockIn) {
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
  if (record.status == AttendanceRecordStatus.absent) {
    return 'Missing Clock In & Clock Out for ${dateLabel(record.date)}';
  }
  if (record.clockInTime == '--' && record.clockOutTime == '--') {
    return 'Missing Clock In & Clock Out for ${dateLabel(record.date)}';
  }
  if (record.clockOutTime == '--') {
    return 'Missing Clock Out for ${dateLabel(record.date)}';
  }
  if (record.clockInTime == '--') {
    return 'Missing Clock In for ${dateLabel(record.date)}';
  }
  return 'Attendance correction requested for ${dateLabel(record.date)}';
}

String _timeValue(String? value) {
  final String trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '--';
  }
  return trimmed;
}
