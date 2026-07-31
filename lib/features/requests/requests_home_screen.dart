import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pulseclock/features/approvals/approvals_home_screen.dart';
import 'package:pulseclock/features/approvals/data/approval_service.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/auth/session/workpulse_session.dart';
import 'package:pulseclock/features/corrections/correction_list_screen.dart';
import 'package:pulseclock/features/corrections/data/correction_service.dart';
import 'package:pulseclock/features/leave/data/leave_service.dart';
import 'package:pulseclock/features/leave/leave_list_screen.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class RequestsHomeScreen extends StatefulWidget {
  const RequestsHomeScreen({super.key});

  @override
  State<RequestsHomeScreen> createState() => _RequestsHomeScreenState();
}

class _RequestsHomeScreenState extends State<RequestsHomeScreen> {
  final WorkPulseMockStore _store = WorkPulseMockStore.instance;
  int? _backendMissedPunchCount;
  int? _backendPendingCorrectionCount;
  int? _backendPendingLeaveCount;
  int? _backendPendingApprovalCount;
  bool _canReviewRequests = false;
  bool _hasStartedBackendLoad = false;
  bool _isLoadingBackendRequestCounts = false;
  bool _hasLoadedBackendRequestCounts = false;
  bool _backendRequestCountLoadFailed = false;

  bool get _usesBackend => SupabaseBootstrap.isInitialized;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String? role = WorkPulseSessionScope.maybeProfileOf(context)?.role;
    _canReviewRequests = const <String>{
      'supervisor',
      'hr',
      'admin',
    }.contains(role);
    if (!_hasStartedBackendLoad) {
      _hasStartedBackendLoad = true;
      _loadBackendRequestCounts();
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

    if (_usesBackend) {
      _loadBackendRequestCounts();
      return;
    }

    setState(() {});
  }

  Future<void> _loadBackendRequestCounts() async {
    if (!_usesBackend) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingBackendRequestCounts = true;
        _backendRequestCountLoadFailed = false;
      });
    }

    try {
      final CorrectionService correctionService = CorrectionService();
      final int missedPunchCount = await correctionService
          .fetchMissedPunchCount();
      final int pendingCorrectionCount = await correctionService
          .fetchPendingCorrectionRequestCount();
      final int pendingLeaveCount = await LeaveService()
          .fetchPendingLeaveRequestCount();
      final ApprovalService approvalService = ApprovalService();
      int? pendingApprovalCount;
      if (_canReviewRequests) {
        pendingApprovalCount =
            (await approvalService.fetchApprovalCounts()).totalPending;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _backendMissedPunchCount = missedPunchCount;
        _backendPendingCorrectionCount = pendingCorrectionCount;
        _backendPendingLeaveCount = pendingLeaveCount;
        _backendPendingApprovalCount = pendingApprovalCount;
        _isLoadingBackendRequestCounts = false;
        _hasLoadedBackendRequestCounts = true;
        _backendRequestCountLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backendMissedPunchCount = null;
        _backendPendingCorrectionCount = null;
        _backendPendingLeaveCount = null;
        _backendPendingApprovalCount = null;
        _isLoadingBackendRequestCounts = false;
        _hasLoadedBackendRequestCounts = false;
        _backendRequestCountLoadFailed = true;
      });
    }
  }

  Future<void> _openCorrections() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return const CorrectionListScreen();
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    await _loadBackendRequestCounts();
  }

  Future<void> _openLeaveRequests() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return const LeaveListScreen();
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    await _loadBackendRequestCounts();
  }

  Future<void> _openApprovals() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return const ApprovalsHomeScreen();
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    await _loadBackendRequestCounts();
  }

  @override
  Widget build(BuildContext context) {
    final int mockPendingLeaveCount = _store.leaveRequests
        .where(
          (LeaveRequest request) =>
              request.status == LeaveRequestStatus.pendingApproval,
        )
        .length;
    final String needActionBadge = _countBadge(
      backendCount: _backendMissedPunchCount,
      mockCount: _store.missedPunchRecords.length,
      label: 'need action',
    );
    final String submittedBadge = _countBadge(
      backendCount: _backendPendingCorrectionCount,
      mockCount: _store.pendingCorrectionRequests.length,
      label: 'submitted',
    );
    final String pendingLeaveBadge = _countBadge(
      backendCount: _backendPendingLeaveCount,
      mockCount: mockPendingLeaveCount,
      label: 'pending',
    );
    final String pendingApprovalBadge = _countBadge(
      backendCount: _backendPendingApprovalCount,
      mockCount: 0,
      label: 'pending',
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
          const Text('Requests', style: PulseClockTextStyles.headerTitle),
          const SizedBox(height: 6),
          const Text(
            'Choose a request module.',
            style: PulseClockTextStyles.headerSubtitle,
          ),
          const SizedBox(height: 18),
          _RequestHubCard(
            title: 'Attendance Corrections',
            subtitle: 'Attendance updates',
            badges: <String>[needActionBadge, submittedBadge],
            icon: Icons.fact_check_outlined,
            backgroundColor: PulseClockColors.statusPendingBg,
            accentColor: PulseClockColors.statusPendingAccent,
            onTap: _openCorrections,
          ),
          const SizedBox(height: 12),
          _RequestHubCard(
            title: 'Leave Requests',
            subtitle: 'Leave management',
            badges: <String>[pendingLeaveBadge],
            icon: Icons.event_available_outlined,
            backgroundColor: PulseClockColors.statusLeaveBg,
            accentColor: PulseClockColors.statusLeaveAccent,
            onTap: _openLeaveRequests,
          ),
          if (_usesBackend && _canReviewRequests) ...<Widget>[
            const SizedBox(height: 12),
            _RequestHubCard(
              title: 'Approvals',
              subtitle: 'Supervisor reviews',
              badges: <String>[pendingApprovalBadge],
              icon: Icons.verified_user_outlined,
              backgroundColor: const Color(0xFFEFF6FF),
              accentColor: PulseClockColors.actionBlue,
              onTap: _openApprovals,
            ),
          ],
        ],
      ),
    );
  }

  String _countBadge({
    required int? backendCount,
    required int mockCount,
    required String label,
  }) {
    if (!_usesBackend) {
      return '$mockCount $label';
    }

    if (_backendRequestCountLoadFailed) {
      return 'Count unavailable';
    }

    if (!_hasLoadedBackendRequestCounts || _isLoadingBackendRequestCounts) {
      return 'Checking';
    }

    return '${backendCount ?? 0} $label';
  }
}

class _RequestHubCard extends StatelessWidget {
  const _RequestHubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
    required this.onTap,
    this.badges = const <String>[],
  });

  final String title;
  final String subtitle;
  final List<String> badges;
  final IconData icon;
  final Color backgroundColor;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SurfaceCard(
        borderRadius: 14,
        padding: const EdgeInsets.all(14),
        color: backgroundColor,
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PulseClockTextStyles.cardTitle.copyWith(
                      color: accentColor,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      color: accentColor.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (badges.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: badges
                          .map(
                            (String badge) => _RequestHubBadge(
                              label: badge,
                              color: accentColor,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: PulseClockColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestHubBadge extends StatelessWidget {
  const _RequestHubBadge({required this.label, required this.color});

  final String label;
  final Color color;

  bool get _isLoading => label == 'Checking';

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PulseClockColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: _isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RotatingCountIcon(color: color),
                  const SizedBox(width: 5),
                  _RequestHubBadgeText(label: label, color: color),
                ],
              )
            : _RequestHubBadgeText(label: label, color: color),
      ),
    );
  }
}

class _RequestHubBadgeText extends StatelessWidget {
  const _RequestHubBadgeText({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: PulseClockTextStyles.cardSubtitle.copyWith(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _RotatingCountIcon extends StatefulWidget {
  const _RotatingCountIcon({required this.color});

  final Color color;

  @override
  State<_RotatingCountIcon> createState() => _RotatingCountIconState();
}

class _RotatingCountIconState extends State<_RotatingCountIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: child,
        );
      },
      child: Icon(Icons.autorenew_rounded, size: 13, color: widget.color),
    );
  }
}
