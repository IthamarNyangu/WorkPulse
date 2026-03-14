import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pulseclock/features/attendance/clock/clock_confirmation_screen.dart';
import 'package:pulseclock/features/attendance/history/attendance_history_screen.dart';
import 'package:pulseclock/features/profile/profile_screen.dart';
import 'package:pulseclock/features/requests/requests_home_screen.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
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
  Timer? _clockTimer;
  DateTime? _punchInAt;
  DateTime? _punchOutAt;
  Duration? _lastWorkedDuration;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
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
    _clockTimer?.cancel();
    super.dispose();
  }

  void _onPrimaryActionPressed() async {
    final ClockActionMode mode = _status == AttendanceStatus.offDuty
        ? ClockActionMode.clockIn
        : ClockActionMode.clockOut;

    final ClockConfirmationResult? result = await Navigator.of(
      context,
    ).push<ClockConfirmationResult>(
      MaterialPageRoute<ClockConfirmationResult>(
        builder: (BuildContext context) => ClockConfirmationScreen(mode: mode),
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
        return const RequestsHomeScreen();
      case 3:
        return const ProfileScreen();
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
    final String punchInLabel = _punchInAt == null ? '--' : timeLabel(_punchInAt!);
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
            child: Image.asset('assets/images/workpulse-bg.png', fit: BoxFit.cover),
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
