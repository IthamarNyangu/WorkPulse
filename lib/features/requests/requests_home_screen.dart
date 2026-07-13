import 'package:flutter/material.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
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

  bool get _usesBackend => SupabaseBootstrap.isInitialized;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _loadBackendRequestCounts();
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

    try {
      final CorrectionService correctionService = CorrectionService();
      final int missedPunchCount = await correctionService
          .fetchMissedPunchCount();
      final int pendingCorrectionCount = await correctionService
          .fetchPendingCorrectionRequestCount();
      final int pendingLeaveCount = await LeaveService()
          .fetchPendingLeaveRequestCount();
      if (!mounted) {
        return;
      }
      setState(() {
        _backendMissedPunchCount = missedPunchCount;
        _backendPendingCorrectionCount = pendingCorrectionCount;
        _backendPendingLeaveCount = pendingLeaveCount;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backendMissedPunchCount = null;
        _backendPendingCorrectionCount = null;
        _backendPendingLeaveCount = null;
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

  @override
  Widget build(BuildContext context) {
    final int missedCount = _usesBackend
        ? (_backendMissedPunchCount ?? 0)
        : _store.missedPunchRecords.length;
    final int pendingCorrectionCount = _usesBackend
        ? (_backendPendingCorrectionCount ?? 0)
        : _store.pendingCorrectionRequests.length;
    final int pendingLeaveCount = _usesBackend
        ? (_backendPendingLeaveCount ?? 0)
        : _store.leaveRequests
              .where(
                (LeaveRequest request) =>
                    request.status == LeaveRequestStatus.pendingApproval,
              )
              .length;

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
            subtitle:
                '$missedCount missed punch | $pendingCorrectionCount pending requests',
            icon: Icons.fact_check_outlined,
            backgroundColor: PulseClockColors.statusPendingBg,
            accentColor: PulseClockColors.statusPendingAccent,
            onTap: _openCorrections,
          ),
          const SizedBox(height: 12),
          _RequestHubCard(
            title: 'Leave Requests',
            subtitle:
                '$pendingLeaveCount pending leave request${pendingLeaveCount == 1 ? '' : 's'}',
            icon: Icons.event_available_outlined,
            backgroundColor: PulseClockColors.statusLeaveBg,
            accentColor: PulseClockColors.statusLeaveAccent,
            onTap: _openLeaveRequests,
          ),
        ],
      ),
    );
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
  });

  final String title;
  final String subtitle;
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
                      color: accentColor.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
