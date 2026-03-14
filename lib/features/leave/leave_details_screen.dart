import 'package:flutter/material.dart';
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leave request updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LeaveRequest? request = _store.leaveRequestById(widget.requestId);

    if (request == null) {
      return Scaffold(
        backgroundColor: PulseClockColors.appBackground,
        appBar: AppBar(
          title: const Text('Leave Request Details'),
          backgroundColor: PulseClockColors.surface,
          foregroundColor: PulseClockColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Leave request is no longer available.',
              style: PulseClockTextStyles.cardSubtitle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final bool isPending = request.status == LeaveRequestStatus.pendingApproval;
    final bool isSingleDay = _isSameDay(request.startDate, request.endDate);

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Leave Request Details'),
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
                      DetailInfoRow(label: 'Leave Type', value: request.type.label),
                      const SizedBox(height: 10),
                      DetailInfoRow(
                        label: isSingleDay ? 'Date' : 'Date Range',
                        value: isSingleDay
                            ? dateLabel(request.startDate)
                            : '${dateLabel(request.startDate)} - ${dateLabel(request.endDate)}',
                      ),
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
                    ],
                  ),
                ),
                if (isPending) ...<Widget>[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _openEditForm(request),
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
