import 'package:flutter/material.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/leave/data/leave_service.dart';
import 'package:pulseclock/features/leave/leave_form_screen.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class LeaveDetailsScreen extends StatefulWidget {
  const LeaveDetailsScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<LeaveDetailsScreen> createState() => _LeaveDetailsScreenState();
}

class _LeaveDetailsScreenState extends State<LeaveDetailsScreen> {
  final WorkPulseMockStore _store = WorkPulseMockStore.instance;
  LeaveRequest? _request;
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _loadError;

  bool get _usesBackend => SupabaseBootstrap.isInitialized;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _loadRequest();
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
      _loadRequest();
      return;
    }

    setState(() {
      _request = _store.leaveRequestById(widget.requestId);
    });
  }

  Future<void> _loadRequest() async {
    if (!_usesBackend) {
      if (!mounted) {
        return;
      }
      setState(() {
        _request = _store.leaveRequestById(widget.requestId);
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
      final LeaveRequest? request = await LeaveService().fetchLeaveRequestById(
        widget.requestId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _request = request;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _request = null;
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _openEditForm(LeaveRequest request) async {
    final bool? updated = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return LeaveFormScreen(initialRequestId: request.id);
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted || updated != true) {
      return;
    }

    await _loadRequest();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Leave request updated.')));
  }

  Future<void> _confirmDeleteRequest(LeaveRequest request) async {
    if (request.status != LeaveRequestStatus.pendingApproval) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFCFDFE),
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 44,
            vertical: 24,
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            'Delete Request',
            style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
          ),
          content: Text(
            'This pending leave request will be removed from WorkPulse. Do you want to continue?',
            style: PulseClockTextStyles.cardSubtitle.copyWith(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                textStyle: PulseClockTextStyles.cardSubtitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(
                'Cancel',
                style: PulseClockTextStyles.cardSubtitle.copyWith(fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB42318),
                textStyle: PulseClockTextStyles.cardSubtitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      if (_usesBackend) {
        await LeaveService().deletePendingLeaveRequest(requestId: request.id);
      } else {
        _store.deletePendingLeaveRequest(requestId: request.id);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete leave request.')),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Leave request deleted.')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final LeaveRequest? request = _request;

    if (_isLoading) {
      return const _LeaveDetailsLoadingScaffold();
    }

    if (_loadError != null) {
      return _LeaveDetailsMessageScaffold(
        message: 'Unable to load leave request.',
        details: _loadError,
        onRetry: _loadRequest,
      );
    }

    if (request == null) {
      return const _LeaveDetailsMessageScaffold(
        message: 'Leave request is no longer available.',
      );
    }

    final bool isPending = request.status == LeaveRequestStatus.pendingApproval;
    final bool isRejected = request.status == LeaveRequestStatus.rejected;
    final bool isSingleDay = _isSameDay(request.startDate, request.endDate);
    final String? reviewerNote = request.reviewerNote?.trim();

    return Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      appBar: AppBar(
        title: const Text('Leave Request Details'),
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        color: PulseClockColors.appBackgroundSolid,
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
                      DetailInfoRow(
                        label: 'Leave Type',
                        value: request.type.label,
                      ),
                      const SizedBox(height: 10),
                      DetailInfoRow(
                        label: isSingleDay ? 'Date' : 'Date Range',
                        value: isSingleDay
                            ? dateLabel(request.startDate)
                            : '${dateLabel(request.startDate)} - ${dateLabel(request.endDate)}',
                      ),
                      if (request.durationDays != null) ...<Widget>[
                        const SizedBox(height: 10),
                        DetailInfoRow(
                          label: 'Leave Duration',
                          value: request.durationDays == 1
                              ? '1 Working Day'
                              : '${request.durationDays} Working Days',
                        ),
                      ],
                      const SizedBox(height: 10),
                      DetailInfoRow(
                        label: 'Status',
                        value: request.status.label,
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: PulseClockColors.cardBorder),
                      const SizedBox(height: 12),
                      Text(
                        'Reason / Comment',
                        style: PulseClockTextStyles.cardSubtitle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.reason,
                        style: PulseClockTextStyles.cardSubtitle,
                      ),
                      if (isRejected) ...<Widget>[
                        const SizedBox(height: 12),
                        const Divider(color: PulseClockColors.cardBorder),
                        const SizedBox(height: 12),
                        Text(
                          'Reason for Rejection',
                          style: PulseClockTextStyles.cardSubtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB91C1C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reviewerNote == null || reviewerNote.isEmpty
                              ? 'No rejection reason was provided.'
                              : reviewerNote,
                          style: PulseClockTextStyles.cardSubtitle.copyWith(
                            color: PulseClockColors.textPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isPending) ...<Widget>[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isDeleting
                          ? null
                          : () => _openEditForm(request),
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
                      child: const Text('Edit Request'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isDeleting
                          ? null
                          : () => _confirmDeleteRequest(request),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: const Color(0xFFB42318),
                        backgroundColor: const Color(0xFFFDF4F4),
                        elevation: 0,
                        textStyle: PulseClockTextStyles.contextAction.copyWith(
                          color: const Color(0xFFB42318),
                          fontSize: 16,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PulseClockDimensions.cardRadius,
                          ),
                          side: const BorderSide(color: Color(0xFFF3B6B6)),
                        ),
                      ),
                      label: _isDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFB42318),
                                ),
                              ),
                            )
                          : const Text('Delete Request'),
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

class _LeaveDetailsLoadingScaffold extends StatelessWidget {
  const _LeaveDetailsLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      appBar: AppBar(
        title: const Text('Leave Request Details'),
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
}

class _LeaveDetailsMessageScaffold extends StatelessWidget {
  const _LeaveDetailsMessageScaffold({
    required this.message,
    this.details,
    this.onRetry,
  });

  final String message;
  final String? details;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      appBar: AppBar(
        title: const Text('Leave Request Details'),
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (details != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    details!,
                    style: PulseClockTextStyles.cardSubtitle,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (onRetry != null) ...<Widget>[
                  const SizedBox(height: 14),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
