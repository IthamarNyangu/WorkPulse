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
      setState(() {
        _leaveApprovals = leaveApprovals;
        _correctionApprovals = correctionApprovals;
        _reviewedLeaveApprovals = reviewedLeaveApprovals;
        _reviewedCorrectionApprovals = reviewedCorrectionApprovals;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Leave request approved.' : 'Leave request rejected.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _actioningId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Unable to approve leave request.'
                : 'Unable to reject leave request.',
          ),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Correction request approved.'
                : 'Correction request rejected.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _actioningId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Unable to approve correction request.'
                : 'Unable to reject correction request.',
          ),
        ),
      );
    }
  }

  Future<_ReviewNoteResult?> _showReviewDialog({
    required String title,
    required String message,
    required String actionLabel,
    required bool isDestructive,
  }) async {
    final TextEditingController noteController = TextEditingController();

    final _ReviewNoteResult? result = await showDialog<_ReviewNoteResult>(
      context: context,
      builder: (BuildContext context) {
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
                style: PulseClockTextStyles.cardSubtitle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reviewer note (optional)',
                  alignLabelWithHint: true,
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
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(_ReviewNoteResult(note: noteController.text.trim()));
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

    noteController.dispose();
    return result;
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
    final int selectedCount = showingLeave
        ? _leaveApprovals.length
        : showingCorrections
        ? _correctionApprovals.length
        : reviewedApprovals.length;

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
                                          return _CorrectionApprovalCard(
                                            request: request,
                                            isBusy: _actioningId == request.id,
                                            onApprove: () => _reviewCorrection(
                                              request,
                                              approve: true,
                                            ),
                                            onReject: () => _reviewCorrection(
                                              request,
                                              approve: false,
                                            ),
                                          );
                                        }

                                        final Object reviewed =
                                            reviewedApprovals[index];
                                        if (reviewed is LeaveApprovalItem) {
                                          return _ReviewedLeaveApprovalCard(
                                            request: reviewed,
                                          );
                                        }
                                        return _ReviewedCorrectionApprovalCard(
                                          request:
                                              reviewed
                                                  as CorrectionApprovalItem,
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
          const SizedBox(height: 12),
          _ApprovalTextBlock(
            title: 'Issue Summary',
            value: request.issueSummary,
          ),
          const SizedBox(height: 8),
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

class _ReviewedLeaveApprovalCard extends StatelessWidget {
  const _ReviewedLeaveApprovalCard({required this.request});

  final LeaveApprovalItem request;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 12),
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
            label: 'Reviewed',
            value: request.reviewedAt == null
                ? '--'
                : dateLabel(request.reviewedAt!),
          ),
          const SizedBox(height: 12),
          _ApprovalTextBlock(title: 'Reason', value: request.reason),
          if (request.reviewerNote != null &&
              request.reviewerNote!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _ApprovalTextBlock(
              title: 'Reviewer Note',
              value: request.reviewerNote!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewedCorrectionApprovalCard extends StatelessWidget {
  const _ReviewedCorrectionApprovalCard({required this.request});

  final CorrectionApprovalItem request;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 12),
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
            label: 'Reviewed',
            value: request.reviewedAt == null
                ? '--'
                : dateLabel(request.reviewedAt!),
          ),
          const SizedBox(height: 12),
          _ApprovalTextBlock(
            title: 'Issue Summary',
            value: request.issueSummary,
          ),
          const SizedBox(height: 8),
          _ApprovalTextBlock(title: 'Reason', value: request.reason),
          if (request.reviewerNote != null &&
              request.reviewerNote!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _ApprovalTextBlock(
              title: 'Reviewer Note',
              value: request.reviewerNote!,
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
  const _ApprovalTextBlock({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: PulseClockTextStyles.cardSubtitle.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.trim().isEmpty ? '--' : value,
          style: PulseClockTextStyles.cardSubtitle,
        ),
      ],
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
