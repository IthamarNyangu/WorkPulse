import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/clock/clock_confirmation_screen.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/features/attendance/history/attendance_history_screen.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/features/notifications/notifications_screen.dart';
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
  final WorkPulseMockStore _store = WorkPulseMockStore.instance;
  AttendanceStatus _status = AttendanceStatus.offDuty;
  int _selectedNavIndex = 0;
  String _employeeName = 'Ithamar';
  late DateTime _now;
  Timer? _clockTimer;
  DateTime? _punchInAt;
  DateTime? _punchOutAt;
  Duration? _lastWorkedDuration;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _syncStateFromStore();
    _loadEmployeeProfile();
    _loadAttendanceFromBackend();
    _store.addListener(_onStoreChanged);
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
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) {
      return;
    }
    if (SupabaseBootstrap.isInitialized) {
      setState(() {});
      return;
    }
    setState(() {
      _syncStateFromStore();
    });
  }

  void _syncStateFromStore() {
    _status = _store.effectiveHomeAttendanceStatus;
    _punchInAt = _store.livePunchInAt;
    _punchOutAt = _store.livePunchOutAt;
    _lastWorkedDuration = _store.liveWorkedDuration;
  }

  Future<void> _loadEmployeeProfile() async {
    if (!SupabaseBootstrap.isInitialized) {
      return;
    }

    try {
      final WorkPulseUserProfile? profile = await AuthService()
          .fetchCurrentProfile();
      if (!mounted || profile == null || profile.firstName.isEmpty) {
        return;
      }
      setState(() {
        _employeeName = profile.firstName;
      });
    } catch (_) {
      // Preserve existing home experience if profile fetch fails.
    }
  }

  Future<void> _loadAttendanceFromBackend() async {
    if (!SupabaseBootstrap.isInitialized) {
      return;
    }

    try {
      final SupabaseAttendanceRecord? record = await AttendanceService()
          .fetchTodaysAttendance();
      if (!mounted) {
        return;
      }
      _store.syncLiveAttendance(
        punchInAt: record?.clockInAt,
        punchOutAt: record?.clockOutAt,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _syncStateFromBackendRecord(record);
      });
    } catch (_) {
      // Keep the existing mock state if the backend attendance lookup fails.
    }
  }

  void _syncStateFromBackendRecord(SupabaseAttendanceRecord? record) {
    _punchInAt = record?.clockInAt;
    _punchOutAt = record?.clockOutAt;
    _lastWorkedDuration = _workedDurationFor(record);

    switch (record?.status) {
      case 'on_duty':
        _status = AttendanceStatus.onDuty;
        return;
      case 'leave_pending':
        _status = AttendanceStatus.leavePending;
        return;
      case 'on_leave':
        _status = AttendanceStatus.onLeave;
        return;
      default:
        _status = AttendanceStatus.offDuty;
    }
  }

  Duration? _workedDurationFor(SupabaseAttendanceRecord? record) {
    if (record?.clockInAt == null) {
      return null;
    }
    if (record!.clockOutAt != null &&
        !record.clockOutAt!.isBefore(record.clockInAt!)) {
      return record.clockOutAt!.difference(record.clockInAt!);
    }
    return null;
  }

  void _onPrimaryActionPressed() async {
    if (_status != AttendanceStatus.offDuty &&
        _status != AttendanceStatus.onDuty) {
      return;
    }

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

    _store.applyClockConfirmationResult(result);
    if (SupabaseBootstrap.isInitialized) {
      await _loadAttendanceFromBackend();
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return const NotificationsScreen();
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
          employeeName: _employeeName,
          statusCard: _statusCardForHome(),
          summary: _summaryForHome(),
          onPrimaryActionPressed: _onPrimaryActionPressed,
          onNotificationsPressed: _openNotifications,
          unreadNotifications: _store.unreadNotificationCount,
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
          employeeName: _employeeName,
          statusCard: _statusCardForHome(),
          summary: _summaryForHome(),
          onPrimaryActionPressed: _onPrimaryActionPressed,
          onNotificationsPressed: _openNotifications,
          unreadNotifications: _store.unreadNotificationCount,
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
      case AttendanceStatus.leavePending:
        return const StatusCardModel(
          title: 'Leave Pending',
          subtitle: 'Your leave request for today is awaiting approval',
          icon: Icons.schedule_outlined,
          backgroundColor: PulseClockColors.statusPendingBg,
          accentColor: PulseClockColors.statusPendingAccent,
        );
      case AttendanceStatus.onLeave:
        return const StatusCardModel(
          title: 'On Leave',
          subtitle: 'Approved leave is active for today',
          icon: Icons.beach_access_outlined,
          backgroundColor: PulseClockColors.statusLeaveBg,
          accentColor: PulseClockColors.statusLeaveAccent,
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

    if (_status == AttendanceStatus.leavePending ||
        _status == AttendanceStatus.onLeave) {
      return const SummaryModel(
        punchIn: '--',
        punchOut: '--',
        workHours: '0h 0m',
      );
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
          if (index == 0 && SupabaseBootstrap.isInitialized) {
            _loadEmployeeProfile();
            _loadAttendanceFromBackend();
          }
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
    required this.employeeName,
    required this.statusCard,
    required this.summary,
    required this.onPrimaryActionPressed,
    required this.onNotificationsPressed,
    required this.unreadNotifications,
  });

  final DateTime now;
  final AttendanceStatus status;
  final String employeeName;
  final StatusCardModel statusCard;
  final SummaryModel summary;
  final VoidCallback onPrimaryActionPressed;
  final VoidCallback onNotificationsPressed;
  final int unreadNotifications;

  bool get _showsPrimaryAction {
    return status == AttendanceStatus.offDuty ||
        status == AttendanceStatus.onDuty;
  }

  @override
  Widget build(BuildContext context) {
    final PrimaryActionModel? primaryAction = _showsPrimaryAction
        ? primaryActionFor(status)
        : null;

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
          HeaderSection(
            employeeName: employeeName,
            onNotificationsPressed: onNotificationsPressed,
            unreadNotificationCount: unreadNotifications,
          ),
          const SizedBox(height: 50),
          LiveTimeSection(now: now),
          const SizedBox(height: 20),
          StatusCardSection(model: statusCard),
          if (primaryAction != null) ...<Widget>[
            const SizedBox(height: 16),
            PrimaryActionButtonSection(
              model: primaryAction,
              onPressed: onPrimaryActionPressed,
              showIcon: false,
            ),
          ],
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
