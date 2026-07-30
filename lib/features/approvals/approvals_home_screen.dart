import 'package:flutter/material.dart';
import 'package:pulseclock/features/approvals/data/approval_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class ApprovalsHomeScreen extends StatefulWidget {
  const ApprovalsHomeScreen({super.key});

  @override
  State<ApprovalsHomeScreen> createState() => _ApprovalsHomeScreenState();
}

class _ApprovalsHomeScreenState extends State<ApprovalsHomeScreen> {
  final ApprovalService _approvalService = ApprovalService();

  _ApprovalQueue _selectedQueue = _ApprovalQueue.leave;
  List<LeaveApprovalItem> _leaveApprovals = <LeaveApprovalItem>[];
  List<CorrectionApprovalItem> _correctionApprovals =
      <CorrectionApprovalItem>[];
  List<LeaveApprovalItem> _reviewedLeaveApprovals = <LeaveApprovalItem>[];
  List<CorrectionApprovalItem> _reviewedCorrectionApprovals =
      <CorrectionApprovalItem>[];
  bool _isLoading = true;
  String? _loadError;
  String? _actioningId;
  int _reviewedPage = 0;

  static const int _reviewedPageSize = 8;

  @override
  void initState() {
    super.initState();
    _loadApprovals();
  }

  Future<void> _loadApprovals({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final List<LeaveApprovalItem> leaveApprovals = await _approvalService
          .fetchPendingLeaveApprovals();
      final List<CorrectionApprovalItem> correctionApprovals =
          await _approvalService.fetchPendingCorrectionApprovals();
      final List<LeaveApprovalItem> reviewedLeaveApprovals =
          await _approvalService.fetchReviewedLeaveApprovals();
      final List<CorrectionApprovalItem> reviewedCorrectionApprovals =
          await _approvalService.fetchReviewedCorrectionApprovals();
      if (!mounted) {
        return;
      }
      final int reviewedTotal =
          reviewedLeaveApprovals.length + reviewedCorrectionApprovals.length;
      final int maxReviewedPage = reviewedTotal == 0
          ? 0
          : (reviewedTotal - 1) ~/ _reviewedPageSize;
      setState(() {
        _leaveApprovals = leaveApprovals;
        _correctionApprovals = correctionApprovals;
        _reviewedLeaveApprovals = reviewedLeaveApprovals;
        _reviewedCorrectionApprovals = reviewedCorrectionApprovals;
        if (_reviewedPage > maxReviewedPage) {
          _reviewedPage = maxReviewedPage;
        }
        _isLoading = false;
        _actioningId = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _leaveApprovals = <LeaveApprovalItem>[];
        _correctionApprovals = <CorrectionApprovalItem>[];
        _reviewedLeaveApprovals = <LeaveApprovalItem>[];
        _reviewedCorrectionApprovals = <CorrectionApprovalItem>[];
        _isLoading = false;
        _actioningId = null;
        _loadError = error.toString();
      });
    }
  }

  void _showResultSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  Future<void> _reviewLeave(
    LeaveApprovalItem request, {
    required bool approve,
  }) async {
    final _ReviewNoteResult? result = await _showReviewDialog(
      title: approve ? 'Approve Leave' : 'Reject Leave',
      message: approve
          ? 'This leave request will be approved.'
          : 'This leave request will be rejected.',
      actionLabel: approve ? 'Approve' : 'Reject',
      isDestructive: !approve,
      noteLabel: approve ? 'Reviewer note (optional)' : 'Reason for rejection',
      requireNote: !approve,
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _actioningId = request.id;
    });

    try {
      if (approve) {
        await _approvalService.approveLeave(
          requestId: request.id,
          reviewerNote: result.note,
        );
      } else {
        await _approvalService.rejectLeave(
          requestId: request.id,
          reviewerNote: result.note,
        );
      }
      await _loadApprovals(showLoading: false);
      if (!mounted) {
        return;
      }
      _showResultSnackBar(
        approve ? 'Leave request approved.' : 'Leave request rejected.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _actioningId = null;
      });
      _showResultSnackBar(
        approve
            ? 'Unable to approve leave request.'
            : 'Unable to reject leave request.',
      );
    }
  }

  Future<void> _reviewCorrection(
    CorrectionApprovalItem request, {
    required bool approve,
  }) async {
    final _ReviewNoteResult? result = await _showReviewDialog(
      title: approve ? 'Approve Correction' : 'Reject Correction',
      message: approve
          ? 'This correction will update the attendance record.'
          : 'This correction request will be rejected.',
      actionLabel: approve ? 'Approve' : 'Reject',
      isDestructive: !approve,
      noteLabel: approve ? '' : 'Reviewer note (optional)',
      requireNote: false,
      showNoteField: !approve,
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _actioningId = request.id;
    });

    try {
      if (approve) {
        await _approvalService.approveCorrection(
          request: request,
          reviewerNote: result.note,
        );
      } else {
        await _approvalService.rejectCorrection(
          request: request,
          reviewerNote: result.note,
        );
      }
      await _loadApprovals(showLoading: false);
      if (!mounted) {
        return;
      }
      _showResultSnackBar(
        approve
            ? 'Correction request approved.'
            : 'Correction request rejected.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _actioningId = null;
      });
      _showResultSnackBar(
        approve
            ? 'Unable to approve correction request.'
            : 'Unable to reject correction request.',
      );
    }
  }

  Future<_ReviewNoteResult?> _showReviewDialog({
    required String title,
    required String message,
    required String actionLabel,
    required bool isDestructive,
    required String noteLabel,
    required bool requireNote,
    bool showNoteField = true,
  }) async {
    final TextEditingController noteController = TextEditingController();
    String? noteError;

    final _ReviewNoteResult? result = await showDialog<_ReviewNoteResult>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFCFDFE),
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                title,
                style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontSize: 14,
                    ),
                  ),
                  if (showNoteField) ...<Widget>[
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      onChanged: (_) {
                        if (noteError == null) {
                          return;
                        }
                        setDialogState(() {
                          noteError = null;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: noteLabel,
                        alignLabelWithHint: true,
                        errorText: noteError,
                        filled: true,
                        fillColor: PulseClockColors.surfaceMuted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: PulseClockColors.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: PulseClockColors.cardBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: PulseClockColors.actionBlue,
                            width: 1.4,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFB42318),
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFB42318),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final String note = showNoteField
                        ? noteController.text.trim()
                        : '';
                    if (requireNote && note.isEmpty) {
                      setDialogState(() {
                        noteError = 'Enter a reason before rejecting.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(_ReviewNoteResult(note: note));
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: isDestructive
                        ? const Color(0xFFB42318)
                        : PulseClockColors.actionBlue,
                    textStyle: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(actionLabel),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();
    return result;
  }

  Future<void> _openCorrectionApprovalDetails(
    CorrectionApprovalItem request,
  ) async {
    final _ApprovalDecision? decision = await Navigator.of(context).push(
      PageRouteBuilder<_ApprovalDecision>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return _PendingCorrectionApprovalDetailsScreen(request: request);
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted || decision == null) {
      return;
    }

    await _reviewCorrection(
      request,
      approve: decision == _ApprovalDecision.approve,
    );
  }

  Future<void> _openReviewedDetails(Object request) async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return _ReviewedApprovalDetailsScreen(request: request);
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showingLeave = _selectedQueue == _ApprovalQueue.leave;
    final bool showingCorrections =
        _selectedQueue == _ApprovalQueue.corrections;
    final List<Object> reviewedApprovals = <Object>[
      ..._reviewedLeaveApprovals,
      ..._reviewedCorrectionApprovals,
    ];
    reviewedApprovals.sort((Object a, Object b) {
      final DateTime aDate = a is LeaveApprovalItem
          ? (a.reviewedAt ?? a.submittedAt)
          : ((a as CorrectionApprovalItem).reviewedAt ?? a.submittedAt);
      final DateTime bDate = b is LeaveApprovalItem
          ? (b.reviewedAt ?? b.submittedAt)
          : ((b as CorrectionApprovalItem).reviewedAt ?? b.submittedAt);
      return bDate.compareTo(aDate);
    });
    final int reviewedPageCount = reviewedApprovals.isEmpty
        ? 1
        : ((reviewedApprovals.length - 1) ~/ _reviewedPageSize) + 1;
    final int safeReviewedPage = _reviewedPage >= reviewedPageCount
        ? reviewedPageCount - 1
        : _reviewedPage;
    final List<Object> pagedReviewedApprovals = reviewedApprovals
        .skip(safeReviewedPage * _reviewedPageSize)
        .take(_reviewedPageSize)
        .toList(growable: false);
    final bool showReviewedPagination =
        _selectedQueue == _ApprovalQueue.reviewed &&
        reviewedApprovals.length > _reviewedPageSize;
    final int selectedCount = showingLeave
        ? _leaveApprovals.length
        : showingCorrections
        ? _correctionApprovals.length
        : pagedReviewedApprovals.length + (showReviewedPagination ? 1 : 0);

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Approvals'),
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
                _ApprovalSummaryCard(
                  leaveCount: _leaveApprovals.length,
                  correctionCount: _correctionApprovals.length,
                ),
                const SizedBox(height: 12),
                HistoryFilterChipBar<_ApprovalQueue>(
                  items: _ApprovalQueue.values,
                  selectedValue: _selectedQueue,
                  labelBuilder: (_ApprovalQueue queue) => queue.label,
                  onSelected: (_ApprovalQueue queue) {
                    if (queue == _selectedQueue) {
                      return;
                    }
                    setState(() {
                      _selectedQueue = queue;
                      if (queue == _ApprovalQueue.reviewed) {
                        _reviewedPage = 0;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoading
                      ? const _ApprovalsLoadingState()
                      : _loadError != null
                      ? _ApprovalsErrorState(
                          message: _loadError!,
                          onRetry: _loadApprovals,
                        )
                      : RefreshIndicator(
                          onRefresh: _loadApprovals,
                          child: selectedCount == 0
                              ? _NoApprovalsState(queue: _selectedQueue)
                              : ListView.separated(
                                  itemCount: selectedCount,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                        if (showingLeave) {
                                          final LeaveApprovalItem request =
                                              _leaveApprovals[index];
                                          return _LeaveApprovalCard(
                                            request: request,
                                            isBusy: _actioningId == request.id,
                                            onApprove: () => _reviewLeave(
                                              request,
                                              approve: true,
                                            ),
                                            onReject: () => _reviewLeave(
                                              request,
                                              approve: false,
                                            ),
                                          );
                                        }

                                        if (showingCorrections) {
                                          final CorrectionApprovalItem request =
                                              _correctionApprovals[index];
                                          return _CorrectionApprovalSummaryCard(
                                            request: request,
                                            isBusy: _actioningId == request.id,
                                            onTap: () =>
                                                _openCorrectionApprovalDetails(
                                                  request,
                                                ),
                                          );
                                        }

                                        if (index >=
                                            pagedReviewedApprovals.length) {
                                          return _ReviewedPaginationControls(
                                            currentPage: safeReviewedPage,
                                            pageCount: reviewedPageCount,
                                            onPrevious: safeReviewedPage == 0
                                                ? null
                                                : () {
                                                    setState(() {
                                                      _reviewedPage =
                                                          safeReviewedPage - 1;
                                                    });
                                                  },
                                            onNext:
                                                safeReviewedPage >=
                                                    reviewedPageCount - 1
                                                ? null
                                                : () {
                                                    setState(() {
                                                      _reviewedPage =
                                                          safeReviewedPage + 1;
                                                    });
                                                  },
                                          );
                                        }

                                        final Object reviewed =
                                            pagedReviewedApprovals[index];
                                        if (reviewed is LeaveApprovalItem) {
                                          return _ReviewedLeaveApprovalCard(
                                            request: reviewed,
                                            onTap: () =>
                                                _openReviewedDetails(reviewed),
                                          );
                                        }
                                        return _ReviewedCorrectionApprovalCard(
                                          request:
                                              reviewed
                                                  as CorrectionApprovalItem,
                                          onTap: () =>
                                              _openReviewedDetails(reviewed),
                                        );
                                      },
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApprovalSummaryCard extends StatelessWidget {
  const _ApprovalSummaryCard({
    required this.leaveCount,
    required this.correctionCount,
  });

  final int leaveCount;
  final int correctionCount;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      borderRadius: 14,
      padding: const EdgeInsets.all(14),
      color: PulseClockColors.statusPendingBg,
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: PulseClockColors.statusPendingAccent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Reviews',
                  style: PulseClockTextStyles.cardTitle.copyWith(
                    color: PulseClockColors.statusPendingAccent,
                    fontSize: 21,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$leaveCount leave | $correctionCount correction',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    color: PulseClockColors.statusPendingAccent,
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

class _LeaveApprovalCard extends StatelessWidget {
  const _LeaveApprovalCard({
    required this.request,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final LeaveApprovalItem request;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      borderRadius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ApprovalEmployeeHeader(employee: request.employee),
          const SizedBox(height: 12),
          DetailInfoRow(label: 'Leave Type', value: request.type.label),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: request.durationDays == 1 ? 'Date' : 'Date Range',
            value: _leaveDateRangeLabel(request.startDate, request.endDate),
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Duration',
            value: request.durationDays == 1
                ? 'Single Day'
                : '${request.durationDays} Days',
          ),
          const SizedBox(height: 12),
          _ApprovalTextBlock(title: 'Reason', value: request.reason),
          const SizedBox(height: 12),
          _ApprovalActions(
            isBusy: isBusy,
            onApprove: onApprove,
            onReject: onReject,
          ),
        ],
      ),
    );
  }
}

class _CorrectionApprovalSummaryCard extends StatelessWidget {
  const _CorrectionApprovalSummaryCard({
    required this.request,
    required this.isBusy,
    required this.onTap,
  });

  final CorrectionApprovalItem request;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isBusy ? null : onTap,
      child: SurfaceCard(
        borderRadius: 14,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReviewedCardHeader(
                    employee: request.employee,
                    statusBadge: _CorrectionApprovalStatusBadge(
                      status: request.status,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DetailInfoRow(label: 'Request Type', value: 'Correction'),
                  const SizedBox(height: 7),
                  DetailInfoRow(
                    label: 'Affected Date',
                    value: dateLabel(request.affectedDate),
                  ),
                  const SizedBox(height: 7),
                  DetailInfoRow(
                    label: 'Correction Type',
                    value: request.correctionType.label,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: PulseClockColors.textSecondary,
                  ),
          ],
        ),
      ),
    );
  }
}

class _CorrectionApprovalCard extends StatelessWidget {
  const _CorrectionApprovalCard({
    required this.request,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final CorrectionApprovalItem request;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      borderRadius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ApprovalEmployeeHeader(employee: request.employee),
          const SizedBox(height: 12),
          _CorrectionApprovalInfoPanel(request: request),
          const SizedBox(height: 12),
          _ApprovalTextBlock(
            title: 'Issue Summary',
            value: request.issueSummary,
            accentColor: PulseClockColors.actionBlue,
            backgroundColor: const Color(0xFFF3F7FF),
          ),
          const SizedBox(height: 8),
          _ApprovalTextBlock(
            title: 'Reason',
            value: request.reason,
            accentColor: PulseClockColors.actionBlue,
            backgroundColor: PulseClockColors.surfaceMuted,
          ),
          const SizedBox(height: 12),
          _ApprovalActions(
            isBusy: isBusy,
            onApprove: onApprove,
            onReject: onReject,
          ),
        ],
      ),
    );
  }
}

class _CorrectionApprovalInfoPanel extends StatelessWidget {
  const _CorrectionApprovalInfoPanel({required this.request});

  final CorrectionApprovalItem request;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PulseClockColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Details',
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.actionBlue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          DetailInfoRow(
            label: 'Affected Date',
            value: dateLabel(request.affectedDate),
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Correction Type',
            value: request.correctionType.label,
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Original Clock In',
            value: _timeOrPlaceholder(request.originalClockInAt),
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Original Clock Out',
            value: _timeOrPlaceholder(request.originalClockOutAt),
          ),
          const Divider(height: 20, color: PulseClockColors.cardBorder),
          DetailInfoRow(
            label: 'Corrected Clock In',
            value: _timeOrPlaceholder(request.correctedClockInAt),
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Corrected Clock Out',
            value: _timeOrPlaceholder(request.correctedClockOutAt),
          ),
        ],
      ),
    );
  }
}

class _PendingCorrectionApprovalDetailsScreen extends StatelessWidget {
  const _PendingCorrectionApprovalDetailsScreen({required this.request});

  final CorrectionApprovalItem request;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      appBar: AppBar(
        title: const Text('Correction Approval Details'),
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PulseClockDimensions.horizontalPadding,
            PulseClockDimensions.topPadding,
            PulseClockDimensions.horizontalPadding,
            28,
          ),
          child: _CorrectionApprovalCard(
            request: request,
            isBusy: false,
            onApprove: () =>
                Navigator.of(context).pop(_ApprovalDecision.approve),
            onReject: () => Navigator.of(context).pop(_ApprovalDecision.reject),
          ),
        ),
      ),
    );
  }
}

class _ReviewedLeaveApprovalCard extends StatelessWidget {
  const _ReviewedLeaveApprovalCard({
    required this.request,
    required this.onTap,
  });

  final LeaveApprovalItem request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SurfaceCard(
        borderRadius: 14,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewedCardHeader(
              employee: request.employee,
              statusBadge: _LeaveApprovalStatusBadge(status: request.status),
            ),
            const SizedBox(height: 10),
            DetailInfoRow(label: 'Request Type', value: 'Leave'),
            const SizedBox(height: 7),
            DetailInfoRow(label: 'Leave Type', value: request.type.label),
            const SizedBox(height: 7),
            DetailInfoRow(
              label: request.durationDays == 1 ? 'Date' : 'Date Range',
              value: _leaveDateRangeLabel(request.startDate, request.endDate),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.chevron_right_rounded,
                color: PulseClockColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewedCorrectionApprovalCard extends StatelessWidget {
  const _ReviewedCorrectionApprovalCard({
    required this.request,
    required this.onTap,
  });

  final CorrectionApprovalItem request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SurfaceCard(
        borderRadius: 14,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewedCardHeader(
              employee: request.employee,
              statusBadge: _CorrectionApprovalStatusBadge(
                status: request.status,
              ),
            ),
            const SizedBox(height: 10),
            DetailInfoRow(label: 'Request Type', value: 'Correction'),
            const SizedBox(height: 7),
            DetailInfoRow(
              label: 'Affected Date',
              value: dateLabel(request.affectedDate),
            ),
            const SizedBox(height: 7),
            DetailInfoRow(
              label: 'Correction Type',
              value: request.correctionType.label,
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.chevron_right_rounded,
                color: PulseClockColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewedCardHeader extends StatelessWidget {
  const _ReviewedCardHeader({
    required this.employee,
    required this.statusBadge,
  });

  final ApprovalEmployeeProfile employee;
  final Widget statusBadge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.fullName,
                style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 2),
              Text(
                employee.employeeId,
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        statusBadge,
      ],
    );
  }
}

class _ReviewedPaginationControls extends StatelessWidget {
  const _ReviewedPaginationControls({
    required this.currentPage,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: onPrevious,
            style: _reviewedPaginationButtonStyle(),
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Previous'),
          ),
          Expanded(
            child: Text(
              'Page ${currentPage + 1} of $pageCount',
              textAlign: TextAlign.center,
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: onNext,
            style: _reviewedPaginationButtonStyle(),
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _reviewedPaginationButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: PulseClockColors.actionBlue,
    foregroundColor: PulseClockColors.surface,
    disabledBackgroundColor: PulseClockColors.surfaceMuted,
    disabledForegroundColor: PulseClockColors.textSecondary.withValues(
      alpha: 0.72,
    ),
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    textStyle: PulseClockTextStyles.contextAction.copyWith(
      color: PulseClockColors.surface,
      fontSize: 12,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

class _ReviewedApprovalDetailsScreen extends StatelessWidget {
  const _ReviewedApprovalDetailsScreen({required this.request});

  final Object request;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      appBar: AppBar(
        title: const Text('Reviewed Request Details'),
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PulseClockDimensions.horizontalPadding,
            PulseClockDimensions.topPadding,
            PulseClockDimensions.horizontalPadding,
            28,
          ),
          child: request is LeaveApprovalItem
              ? _ReviewedLeaveDetails(request: request as LeaveApprovalItem)
              : _ReviewedCorrectionDetails(
                  request: request as CorrectionApprovalItem,
                ),
        ),
      ),
    );
  }
}

class _ReviewedLeaveDetails extends StatelessWidget {
  const _ReviewedLeaveDetails({required this.request});

  final LeaveApprovalItem request;

  @override
  Widget build(BuildContext context) {
    final String reviewerNote = request.reviewerNote?.trim() ?? '';
    final bool isRejected = request.status == LeaveRequestStatus.rejected;

    return SurfaceCard(
      borderRadius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ApprovalEmployeeHeader(employee: request.employee),
              ),
              const SizedBox(width: 8),
              _LeaveApprovalStatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 14),
          DetailInfoRow(label: 'Request Type', value: 'Leave'),
          const SizedBox(height: 8),
          DetailInfoRow(label: 'Leave Type', value: request.type.label),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: request.durationDays == 1 ? 'Date' : 'Date Range',
            value: _leaveDateRangeLabel(request.startDate, request.endDate),
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Duration',
            value: request.durationDays == 1
                ? 'Single Day'
                : '${request.durationDays} Days',
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Reviewed',
            value: request.reviewedAt == null
                ? '--'
                : dateLabel(request.reviewedAt!),
          ),
          const SizedBox(height: 14),
          _ApprovalTextBlock(title: 'Reason / Comment', value: request.reason),
          if (isRejected || reviewerNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _ApprovalTextBlock(
              title: isRejected ? 'Reason for Rejection' : 'Reviewer Note',
              value: reviewerNote.isEmpty
                  ? 'No rejection reason was provided.'
                  : reviewerNote,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewedCorrectionDetails extends StatelessWidget {
  const _ReviewedCorrectionDetails({required this.request});

  final CorrectionApprovalItem request;

  @override
  Widget build(BuildContext context) {
    final String reviewerNote = request.reviewerNote?.trim() ?? '';

    return SurfaceCard(
      borderRadius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ApprovalEmployeeHeader(employee: request.employee),
              ),
              const SizedBox(width: 8),
              _CorrectionApprovalStatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 14),
          DetailInfoRow(label: 'Request Type', value: 'Correction'),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Affected Date',
            value: dateLabel(request.affectedDate),
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Correction Type',
            value: request.correctionType.label,
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Original Clock In',
            value: _timeOrPlaceholder(request.originalClockInAt),
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Original Clock Out',
            value: _timeOrPlaceholder(request.originalClockOutAt),
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Corrected Clock In',
            value: _timeOrPlaceholder(request.correctedClockInAt),
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Corrected Clock Out',
            value: _timeOrPlaceholder(request.correctedClockOutAt),
          ),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'Reviewed',
            value: request.reviewedAt == null
                ? '--'
                : dateLabel(request.reviewedAt!),
          ),
          const SizedBox(height: 14),
          _ApprovalTextBlock(
            title: 'Issue Summary',
            value: request.issueSummary,
          ),
          const SizedBox(height: 10),
          _ApprovalTextBlock(title: 'Reason', value: request.reason),
          if (reviewerNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _ApprovalTextBlock(
              title: request.status == CorrectionRequestApprovalStatus.rejected
                  ? 'Reason for Rejection'
                  : 'Reviewer Note',
              value: reviewerNote,
            ),
          ],
        ],
      ),
    );
  }
}

class _ApprovalEmployeeHeader extends StatelessWidget {
  const _ApprovalEmployeeHeader({required this.employee});

  final ApprovalEmployeeProfile employee;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0x142563EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: PulseClockColors.actionBlue,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.fullName,
                style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 2),
              Text(
                'Employee ID: ${employee.employeeId}',
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalTextBlock extends StatelessWidget {
  const _ApprovalTextBlock({
    required this.title,
    required this.value,
    this.accentColor = PulseClockColors.textSecondary,
    this.backgroundColor = PulseClockColors.surfaceMuted,
  });

  final String title;
  final String value;
  final Color accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PulseClockColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: accentColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value.trim().isEmpty ? '--' : value,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalActions extends StatelessWidget {
  const _ApprovalActions({
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: isBusy ? null : onApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: PulseClockColors.actionBlue,
              foregroundColor: PulseClockColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: PulseClockTextStyles.contextAction.copyWith(
                color: PulseClockColors.surface,
                fontSize: 15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        PulseClockColors.surface,
                      ),
                    ),
                  )
                : const Text('Approve'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: isBusy ? null : onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB42318),
              backgroundColor: const Color(0xFFFDF4F4),
              side: const BorderSide(color: Color(0xFFF3B6B6)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: PulseClockTextStyles.contextAction.copyWith(
                color: const Color(0xFFB42318),
                fontSize: 15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reject'),
          ),
        ),
      ],
    );
  }
}

class _NoApprovalsState extends StatelessWidget {
  const _NoApprovalsState({required this.queue});

  final _ApprovalQueue queue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        SurfaceCard(
          child: Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                color: PulseClockColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  queue == _ApprovalQueue.leave
                      ? 'No leave requests need review.'
                      : queue == _ApprovalQueue.corrections
                      ? 'No correction requests need review.'
                      : 'No reviewed approvals yet.',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalsLoadingState extends StatelessWidget {
  const _ApprovalsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(PulseClockColors.surface),
      ),
    );
  }
}

class _ApprovalsErrorState extends StatelessWidget {
  const _ApprovalsErrorState({required this.message, required this.onRetry});

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
              'Unable to load approvals.',
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

class _ReviewNoteResult {
  const _ReviewNoteResult({required this.note});

  final String note;
}

enum _ApprovalDecision { approve, reject }

enum _ApprovalQueue { leave, corrections, reviewed }

extension _ApprovalQueueLabels on _ApprovalQueue {
  String get label {
    switch (this) {
      case _ApprovalQueue.leave:
        return 'Leave';
      case _ApprovalQueue.corrections:
        return 'Corrections';
      case _ApprovalQueue.reviewed:
        return 'Reviewed';
    }
  }
}

class _LeaveApprovalStatusBadge extends StatelessWidget {
  const _LeaveApprovalStatusBadge({required this.status});

  final LeaveRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final _ApprovalStatusStyle style = _leaveStatusStyle(status);
    return _ApprovalStatusPill(label: status.label, style: style);
  }
}

class _CorrectionApprovalStatusBadge extends StatelessWidget {
  const _CorrectionApprovalStatusBadge({required this.status});

  final CorrectionRequestApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final _ApprovalStatusStyle style = _correctionStatusStyle(status);
    return _ApprovalStatusPill(
      label: _correctionStatusLabel(status),
      style: style,
    );
  }
}

class _ApprovalStatusPill extends StatelessWidget {
  const _ApprovalStatusPill({required this.label, required this.style});

  final String label;
  final _ApprovalStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: PulseClockTextStyles.cardSubtitle.copyWith(
          color: style.foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ApprovalStatusStyle {
  const _ApprovalStatusStyle({
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
}

_ApprovalStatusStyle _leaveStatusStyle(LeaveRequestStatus status) {
  switch (status) {
    case LeaveRequestStatus.pendingApproval:
      return const _ApprovalStatusStyle(
        backgroundColor: Color(0x22B45309),
        foregroundColor: Color(0xFFB45309),
      );
    case LeaveRequestStatus.approved:
      return const _ApprovalStatusStyle(
        backgroundColor: Color(0x2215803D),
        foregroundColor: Color(0xFF0F8A43),
      );
    case LeaveRequestStatus.rejected:
      return const _ApprovalStatusStyle(
        backgroundColor: Color(0x22B91C1C),
        foregroundColor: Color(0xFFB91C1C),
      );
  }
}

_ApprovalStatusStyle _correctionStatusStyle(
  CorrectionRequestApprovalStatus status,
) {
  switch (status) {
    case CorrectionRequestApprovalStatus.pending:
      return const _ApprovalStatusStyle(
        backgroundColor: Color(0x22B45309),
        foregroundColor: Color(0xFFB45309),
      );
    case CorrectionRequestApprovalStatus.approved:
      return const _ApprovalStatusStyle(
        backgroundColor: Color(0x2215803D),
        foregroundColor: Color(0xFF0F8A43),
      );
    case CorrectionRequestApprovalStatus.rejected:
      return const _ApprovalStatusStyle(
        backgroundColor: Color(0x22B91C1C),
        foregroundColor: Color(0xFFB91C1C),
      );
  }
}

String _correctionStatusLabel(CorrectionRequestApprovalStatus status) {
  switch (status) {
    case CorrectionRequestApprovalStatus.pending:
      return 'Pending';
    case CorrectionRequestApprovalStatus.approved:
      return 'Approved';
    case CorrectionRequestApprovalStatus.rejected:
      return 'Rejected';
  }
}

String _timeOrPlaceholder(DateTime? dateTime) {
  if (dateTime == null) {
    return '--';
  }
  return timeLabel(dateTime);
}

String _leaveDateRangeLabel(DateTime startDate, DateTime endDate) {
  if (_isSameDay(startDate, endDate)) {
    return dateLabel(startDate);
  }

  final String startMonth = _monthShortName(startDate.month);
  final String endMonth = _monthShortName(endDate.month);
  if (startDate.year == endDate.year && startDate.month == endDate.month) {
    return '${startDate.day} - ${endDate.day} $endMonth ${endDate.year}';
  }
  if (startDate.year == endDate.year) {
    return '${startDate.day} $startMonth - ${endDate.day} $endMonth ${endDate.year}';
  }
  return '${startDate.day} $startMonth ${startDate.year} - ${endDate.day} $endMonth ${endDate.year}';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _monthShortName(int month) {
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}
