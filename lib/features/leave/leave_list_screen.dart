import 'package:flutter/material.dart';
import 'package:pulseclock/features/leave/leave_details_screen.dart';
import 'package:pulseclock/features/leave/leave_form_screen.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class LeaveListScreen extends StatefulWidget {
  const LeaveListScreen({super.key});

  @override
  State<LeaveListScreen> createState() => _LeaveListScreenState();
}

class _LeaveListScreenState extends State<LeaveListScreen> {
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

  Future<void> _openLeaveForm({String? initialRequestId}) async {
    final bool? submitted = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return LeaveFormScreen(initialRequestId: initialRequestId);
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted || submitted != true) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Leave request submitted.')));
  }

  void _openLeaveDetails(LeaveRequest request) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return LeaveDetailsScreen(requestId: request.id);
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<LeaveRequest> leaveRequests = _store.leaveRequests;

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Leave Requests'),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Manage Leave Requests',
                        style: PulseClockTextStyles.headerSubtitle.copyWith(
                          color: PulseClockColors.onBackgroundPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openLeaveForm(),
                      child: const Text('Submit Leave Request'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: leaveRequests.isEmpty
                      ? const _NoLeaveRequestState()
                      : ListView.separated(
                          itemCount: leaveRequests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final LeaveRequest request = leaveRequests[index];
                            return LeaveRequestListCard(
                              request: request,
                              onTap: () => _openLeaveDetails(request),
                            );
                          },
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

class LeaveRequestListCard extends StatelessWidget {
  const LeaveRequestListCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  final LeaveRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool singleDay = _isSameDay(request.startDate, request.endDate);
    final String dateText = singleDay
        ? dateLabel(request.startDate)
        : '${dateLabel(request.startDate)} - ${dateLabel(request.endDate)}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SurfaceCard(
        borderRadius: 14,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.type.label,
                    style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateText,
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            LeaveRequestStatusBadge(status: request.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: PulseClockColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class LeaveRequestStatusBadge extends StatelessWidget {
  const LeaveRequestStatusBadge({super.key, required this.status});

  final LeaveRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final _LeaveRequestBadgeStyle style = _leaveBadgeStyle(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: PulseClockTextStyles.cardSubtitle.copyWith(
          color: style.foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LeaveRequestBadgeStyle {
  const _LeaveRequestBadgeStyle({
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
}

_LeaveRequestBadgeStyle _leaveBadgeStyle(LeaveRequestStatus status) {
  switch (status) {
    case LeaveRequestStatus.pendingApproval:
      return const _LeaveRequestBadgeStyle(
        backgroundColor: Color(0x22B45309),
        foregroundColor: Color(0xFFB45309),
      );
    case LeaveRequestStatus.approved:
      return const _LeaveRequestBadgeStyle(
        backgroundColor: Color(0x2215803D),
        foregroundColor: Color(0xFF0F8A43),
      );
    case LeaveRequestStatus.rejected:
      return const _LeaveRequestBadgeStyle(
        backgroundColor: Color(0x22B91C1C),
        foregroundColor: Color(0xFFB91C1C),
      );
  }
}

class _NoLeaveRequestState extends StatelessWidget {
  const _NoLeaveRequestState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SurfaceCard(
        child: Row(
          children: [
            const Icon(
              Icons.event_busy_outlined,
              color: PulseClockColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No leave requests found.',
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

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
