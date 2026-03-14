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
  _LeaveStatusFilter _selectedStatusFilter = _LeaveStatusFilter.all;
  _LeaveTypeFilter _selectedTypeFilter = _LeaveTypeFilter.all;

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

  bool _matchesStatusFilter(LeaveRequest request) {
    switch (_selectedStatusFilter) {
      case _LeaveStatusFilter.all:
        return true;
      case _LeaveStatusFilter.pendingApproval:
        return request.status == LeaveRequestStatus.pendingApproval;
      case _LeaveStatusFilter.approved:
        return request.status == LeaveRequestStatus.approved;
      case _LeaveStatusFilter.rejected:
        return request.status == LeaveRequestStatus.rejected;
    }
  }

  bool _matchesTypeFilter(LeaveRequest request) {
    switch (_selectedTypeFilter) {
      case _LeaveTypeFilter.all:
        return true;
      case _LeaveTypeFilter.annualLeave:
        return request.type == LeaveType.annualLeave;
      case _LeaveTypeFilter.sickLeave:
        return request.type == LeaveType.sickLeave;
      case _LeaveTypeFilter.other:
        return request.type == LeaveType.other;
    }
  }

  List<LeaveRequest> _filteredLeaveRequests() {
    final Iterable<LeaveRequest> filtered = _store.leaveRequests.where((
      LeaveRequest request,
    ) {
      return _matchesStatusFilter(request) && _matchesTypeFilter(request);
    });

    // Keep newest requests first for scalability and future pagination.
    final List<LeaveRequest> sorted = filtered.toList();
    sorted.sort((LeaveRequest a, LeaveRequest b) {
      return b.submittedAt.compareTo(a.submittedAt);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final List<LeaveRequest> leaveRequests = _filteredLeaveRequests();

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
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: PulseClockColors.surface,
                        backgroundColor: PulseClockColors.actionBlue,
                        textStyle: PulseClockTextStyles.contextAction.copyWith(
                          color: PulseClockColors.surface,
                          fontSize: 15,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _openLeaveForm(),
                      child: const Text('Submit Leave Request'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Status',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    color: PulseClockColors.onBackgroundPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                HistoryFilterChipBar<_LeaveStatusFilter>(
                  items: _LeaveStatusFilter.values,
                  selectedValue: _selectedStatusFilter,
                  labelBuilder: (_LeaveStatusFilter filter) => filter.label,
                  onSelected: (_LeaveStatusFilter filter) {
                    if (filter == _selectedStatusFilter) {
                      return;
                    }
                    setState(() {
                      _selectedStatusFilter = filter;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Leave Type',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    color: PulseClockColors.onBackgroundPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                HistoryFilterChipBar<_LeaveTypeFilter>(
                  items: _LeaveTypeFilter.values,
                  selectedValue: _selectedTypeFilter,
                  labelBuilder: (_LeaveTypeFilter filter) => filter.label,
                  onSelected: (_LeaveTypeFilter filter) {
                    if (filter == _selectedTypeFilter) {
                      return;
                    }
                    setState(() {
                      _selectedTypeFilter = filter;
                    });
                  },
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
    final String dateText = _leaveDateRangeLabel(
      request.startDate,
      request.endDate,
    );
    final int durationDays = _leaveDurationDays(request.startDate, request.endDate);
    final String durationText = singleDay ? 'Single Day' : '$durationDays Days';

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
                  const SizedBox(height: 2),
                  Text(
                    'Duration: $durationText',
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PulseClockColors.textSecondary.withOpacity(0.9),
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

int _leaveDurationDays(DateTime startDate, DateTime endDate) {
  final DateTime start = DateTime(startDate.year, startDate.month, startDate.day);
  final DateTime end = DateTime(endDate.year, endDate.month, endDate.day);
  if (end.isBefore(start)) {
    return 1;
  }
  return end.difference(start).inDays + 1;
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

enum _LeaveStatusFilter { all, pendingApproval, approved, rejected }

extension _LeaveStatusFilterLabels on _LeaveStatusFilter {
  String get label {
    switch (this) {
      case _LeaveStatusFilter.all:
        return 'All';
      case _LeaveStatusFilter.pendingApproval:
        return 'Pending Approval';
      case _LeaveStatusFilter.approved:
        return 'Approved';
      case _LeaveStatusFilter.rejected:
        return 'Rejected';
    }
  }
}

enum _LeaveTypeFilter { all, annualLeave, sickLeave, other }

extension _LeaveTypeFilterLabels on _LeaveTypeFilter {
  String get label {
    switch (this) {
      case _LeaveTypeFilter.all:
        return 'All';
      case _LeaveTypeFilter.annualLeave:
        return 'Annual Leave';
      case _LeaveTypeFilter.sickLeave:
        return 'Sick Leave';
      case _LeaveTypeFilter.other:
        return 'Other';
    }
  }
}
