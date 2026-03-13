import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/screens/attendance_history_screen.dart';
import 'package:pulseclock/pulseclock/screens/clock_confirmation_screen.dart';
import 'package:pulseclock/pulseclock/screens/correction_request_detail_screen.dart';
import 'package:pulseclock/pulseclock/screens/missed_punch_requests_screen.dart';
import 'package:pulseclock/pulseclock/screens/request_detail_screen.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class PulseClockHomeScreen extends StatefulWidget {
  const PulseClockHomeScreen({super.key});

  @override
  State<PulseClockHomeScreen> createState() => _PulseClockHomeScreenState();
}

class _PulseClockHomeScreenState extends State<PulseClockHomeScreen> {
  AttendanceStatus _status = AttendanceStatus.offDuty;
  int _selectedNavIndex = 0;
  late DateTime _now;
  final WorkPulseMockStore _mockStore = WorkPulseMockStore.instance;
  Timer? _clockTimer;
  DateTime? _punchInAt;
  DateTime? _punchOutAt;
  Duration? _lastWorkedDuration;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _mockStore.addListener(_onMockStoreChanged);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _mockStore.removeListener(_onMockStoreChanged);
    _clockTimer?.cancel();
    super.dispose();
  }

  void _onMockStoreChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _onPrimaryActionPressed() async {
    final ClockActionMode mode = _status == AttendanceStatus.offDuty
        ? ClockActionMode.clockIn
        : ClockActionMode.clockOut;

    final ClockConfirmationResult? result = await Navigator.of(context)
        .push<ClockConfirmationResult>(
          MaterialPageRoute<ClockConfirmationResult>(
            builder: (BuildContext context) =>
                ClockConfirmationScreen(mode: mode),
          ),
        );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      if (result.mode == ClockActionMode.clockIn) {
        _status = AttendanceStatus.onDuty;
        _punchInAt = result.timestamp;
        _punchOutAt = null;
        _lastWorkedDuration = null;
      } else {
        _status = AttendanceStatus.offDuty;
        _punchOutAt = result.timestamp;
        if (_punchInAt != null && !_punchOutAt!.isBefore(_punchInAt!)) {
          _lastWorkedDuration = _punchOutAt!.difference(_punchInAt!);
        } else {
          _lastWorkedDuration = Duration.zero;
        }
      }
    });
  }

  void _openRequestDetail(RequestEntryType type) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return RequestDetailScreen(type: type);
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _openMissedPunchRequests() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return const MissedPunchRequestsScreen();
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _openPendingCorrectionDetails() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return const CorrectionRequestDetailScreen();
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedNavIndex) {
      case 0:
        return HomeTabContent(
          now: _now,
          status: _status,
          statusCard: _statusCardForHome(),
          summary: _summaryForHome(),
          onPrimaryActionPressed: _onPrimaryActionPressed,
        );
      case 1:
        return const AttendanceHistoryScreen();
      case 2:
        return RequestsTab(
          missedPunchCount: _mockStore.missedPunchRecords.length,
          pendingRequestCount: _mockStore.pendingCorrectionRequests.length,
          onOpenMissedPunch: _openMissedPunchRequests,
          onOpenPendingCorrection: _openPendingCorrectionDetails,
          onOpenLeaveDetails: () => _openRequestDetail(RequestEntryType.leaveDetails),
        );
      case 3:
        return const ProfileTab();
      default:
        return HomeTabContent(
          now: _now,
          status: _status,
          statusCard: _statusCardForHome(),
          summary: _summaryForHome(),
          onPrimaryActionPressed: _onPrimaryActionPressed,
        );
    }
  }

  StatusCardModel _statusCardForHome() {
    switch (_status) {
      case AttendanceStatus.offDuty:
        return StatusCardModel(
          title: 'Off Duty',
          subtitle: _punchOutAt != null
              ? 'Last clock out at ${timeLabel(_punchOutAt!)}'
              : 'Ready to start your workday',
          icon: Icons.access_time_outlined,
          backgroundColor: PulseClockColors.statusOffDutyBg,
          accentColor: PulseClockColors.statusOffDutyAccent,
        );
      case AttendanceStatus.onDuty:
        return StatusCardModel(
          title: 'On Duty',
          subtitle: _punchInAt != null
              ? 'You clocked in at ${timeLabel(_punchInAt!)}'
              : 'You are currently on duty',
          icon: Icons.check_circle_outline,
          backgroundColor: PulseClockColors.statusOnDutyBg,
          accentColor: PulseClockColors.statusOnDutyAccent,
        );
    }
  }

  SummaryModel _summaryForHome() {
    final String punchInLabel = _punchInAt == null
        ? '--'
        : timeLabel(_punchInAt!);
    final String punchOutLabel = _punchOutAt == null
        ? '--'
        : timeLabel(_punchOutAt!);

    Duration workedDuration = Duration.zero;
    if (_status == AttendanceStatus.onDuty && _punchInAt != null) {
      workedDuration = _now.difference(_punchInAt!);
    } else if (_lastWorkedDuration != null) {
      workedDuration = _lastWorkedDuration!;
    }

    return SummaryModel(
      punchIn: punchInLabel,
      punchOut: punchOutLabel,
      workHours: durationLabel(workedDuration),
    );
  }

  Widget _buildBackgroundLayer(BuildContext context) {
    if (_selectedNavIndex == 0) {
      return Positioned(
        top: -48,
        right: -170,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.09,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x70000000),
                BlendMode.darken,
              ),
              child: Image.asset(
                'assets/images/workpulse-bg.png',
                width: MediaQuery.sizeOf(context).width * 1.45,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.1,
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Color(0x55000000),
              BlendMode.darken,
            ),
            child: Image.asset(
              'assets/images/workpulse-bg.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111827), Color(0x995A1622)],
          ),
        ),
        child: Stack(
          children: [
            _buildBackgroundLayer(context),
            SafeArea(child: _buildTabContent()),
          ],
        ),
      ),
      bottomNavigationBar: PulseBottomNavigation(
        currentIndex: _selectedNavIndex,
        onTap: (int index) {
          setState(() {
            _selectedNavIndex = index;
          });
        },
      ),
    );
  }
}

class HomeTabContent extends StatelessWidget {
  const HomeTabContent({
    super.key,
    required this.now,
    required this.status,
    required this.statusCard,
    required this.summary,
    required this.onPrimaryActionPressed,
  });

  final DateTime now;
  final AttendanceStatus status;
  final StatusCardModel statusCard;
  final SummaryModel summary;
  final VoidCallback onPrimaryActionPressed;

  @override
  Widget build(BuildContext context) {
    final PrimaryActionModel primaryAction = primaryActionFor(status);

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
          const HeaderSection(employeeName: 'Ithamar'),
          const SizedBox(height: 50),
          LiveTimeSection(now: now),
          const SizedBox(height: 20),
          StatusCardSection(model: statusCard),
          const SizedBox(height: 16),
          PrimaryActionButtonSection(
            model: primaryAction,
            onPressed: onPrimaryActionPressed,
          ),
          const SizedBox(height: 24),
          Text(
            "Today's Summary",
            style: PulseClockTextStyles.sectionTitleOnBackground.copyWith(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          SummaryCardsRow(summary: summary, status: status),
          const Spacer(),
        ],
      ),
    );
  }
}

class RequestsTab extends StatelessWidget {
  const RequestsTab({
    super.key,
    required this.missedPunchCount,
    required this.pendingRequestCount,
    required this.onOpenMissedPunch,
    required this.onOpenPendingCorrection,
    required this.onOpenLeaveDetails,
  });

  final int missedPunchCount;
  final int pendingRequestCount;
  final VoidCallback onOpenMissedPunch;
  final VoidCallback onOpenPendingCorrection;
  final VoidCallback onOpenLeaveDetails;

  @override
  Widget build(BuildContext context) {
    final String missedPunchSubtitle = missedPunchCount == 0
        ? 'No missed punch records to correct right now.'
        : '$missedPunchCount missed punch record${missedPunchCount == 1 ? '' : 's'} available.';
    final String pendingSubtitle = pendingRequestCount == 0
        ? 'No pending correction requests.'
        : '$pendingRequestCount pending correction request${pendingRequestCount == 1 ? '' : 's'}.';

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
            'Select an item to view its details.',
            style: PulseClockTextStyles.headerSubtitle,
          ),
          const SizedBox(height: 20),
          RequestOptionCard(
            type: RequestEntryType.missedPunch,
            subtitleOverride: missedPunchSubtitle,
            onTap: onOpenMissedPunch,
          ),
          const SizedBox(height: 12),
          RequestOptionCard(
            type: RequestEntryType.correctionPending,
            subtitleOverride: pendingSubtitle,
            onTap: onOpenPendingCorrection,
          ),
          const SizedBox(height: 12),
          RequestOptionCard(
            type: RequestEntryType.leaveDetails,
            onTap: onOpenLeaveDetails,
          ),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
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
          const Text('Profile', style: PulseClockTextStyles.headerTitle),
          const SizedBox(height: 20),
          const SurfaceCard(
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: PulseClockColors.textSecondary,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Profile settings will appear here.',
                    style: PulseClockTextStyles.cardSubtitle,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Center(
            child: Text(
              'Version demo',
              style: TextStyle(
                fontSize: 10,
                color: Color(0x9FF2D4D7),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
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
          Text(title, style: PulseClockTextStyles.headerTitle),
          const SizedBox(height: 20),
          SurfaceCard(
            child: Row(
              children: [
                Icon(icon, color: PulseClockColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: PulseClockTextStyles.cardSubtitle,
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

class RequestOptionCard extends StatelessWidget {
  const RequestOptionCard({
    super.key,
    required this.type,
    required this.onTap,
    this.subtitleOverride,
  });

  final RequestEntryType type;
  final VoidCallback onTap;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    final RequestEntryModel model = requestEntryFor(type);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SurfaceCard(
        borderRadius: 14,
        padding: const EdgeInsets.all(14),
        color: model.backgroundColor,
        child: Row(
          children: [
            Icon(model.icon, color: model.accentColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.title,
                    style: PulseClockTextStyles.cardTitle.copyWith(
                      color: model.accentColor,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleOverride ?? model.subtitle,
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      color: model.accentColor.withOpacity(0.8),
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
