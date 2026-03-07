import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/styles.dart';

enum AttendanceStatus {
  offDuty,
  onDuty,
  missedPunch,
  correctionPending,
  onLeave,
}

extension AttendanceStatusLabel on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.offDuty:
        return 'Off Duty';
      case AttendanceStatus.onDuty:
        return 'On Duty';
      case AttendanceStatus.missedPunch:
        return 'Missed Punch';
      case AttendanceStatus.correctionPending:
        return 'Correction Pending';
      case AttendanceStatus.onLeave:
        return 'On Leave';
    }
  }
}

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

  void _onPrimaryActionPressed() {
    setState(() {
      switch (_status) {
        case AttendanceStatus.offDuty:
          _status = AttendanceStatus.onDuty;
        case AttendanceStatus.onDuty:
          _status = AttendanceStatus.offDuty;
        case AttendanceStatus.missedPunch:
          _status = AttendanceStatus.correctionPending;
        case AttendanceStatus.correctionPending:
        case AttendanceStatus.onLeave:
          break;
      }
    });
  }

  void _onRequestCorrection() {
    setState(() {
      _status = AttendanceStatus.correctionPending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final StatusCardModel statusCard = _statusCardFor(_status);
    final PrimaryActionModel primaryAction = _primaryActionFor(_status);
    final SummaryModel summary = _summaryFor(_status);
    final bool showContextualCard = _hasContextualCard(_status);

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
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
                const HeaderSection(employeeName: 'Sarah'),
                const SizedBox(height: 18),
                LiveTimeSection(now: _now),
                const SizedBox(height: 20),
                MockStatusSwitcher(
                  currentStatus: _status,
                  onChanged: (AttendanceStatus value) {
                    setState(() {
                      _status = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                StatusCardSection(model: statusCard),
                const SizedBox(height: 16),
                PrimaryActionButtonSection(
                  model: primaryAction,
                  onPressed: _onPrimaryActionPressed,
                ),
                const SizedBox(height: 24),
                const Text(
                  "Today's Summary",
                  style: PulseClockTextStyles.sectionTitleOnBackground,
                ),
                const SizedBox(height: 12),
                SummaryCardsRow(summary: summary, status: _status),
                if (showContextualCard) ...[
                  const SizedBox(height: 16),
                  ContextualCardsSection(
                    status: _status,
                    onRequestCorrection: _onRequestCorrection,
                  ),
                ],
              ],
            ),
          ),
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

class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key, required this.employeeName});

  final String employeeName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PulseClock', style: PulseClockTextStyles.headerTitle),
        const SizedBox(height: 6),
        Text(
          'Welcome back, $employeeName',
          style: PulseClockTextStyles.headerSubtitle,
        ),
      ],
    );
  }
}

class LiveTimeSection extends StatelessWidget {
  const LiveTimeSection({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: PulseClockColors.onBackgroundSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              _weekdayName(now),
              style: PulseClockTextStyles.weekdayOnBackground,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Text(
            _dateLabel(now),
            style: PulseClockTextStyles.dateOnBackground,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: Text(
            _timeLabel(now),
            style: PulseClockTextStyles.timeOnBackground,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class MockStatusSwitcher extends StatelessWidget {
  const MockStatusSwitcher({
    super.key,
    required this.currentStatus,
    required this.onChanged,
  });

  final AttendanceStatus currentStatus;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mock Status', style: PulseClockTextStyles.switcherLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AttendanceStatus.values.map((AttendanceStatus status) {
            final bool selected = status == currentStatus;
            return ChoiceChip(
              label: Text(status.label),
              selected: selected,
              onSelected: (_) => onChanged(status),
              showCheckmark: false,
              selectedColor: PulseClockColors.surface,
              backgroundColor: PulseClockColors.surface.withOpacity(0.18),
              side: BorderSide(
                color: selected
                    ? PulseClockColors.surface
                    : PulseClockColors.surface.withOpacity(0.48),
              ),
              labelStyle: TextStyle(
                color: selected
                    ? PulseClockColors.appBackground
                    : PulseClockColors.surface,
                fontWeight: FontWeight.w600,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class StatusCardSection extends StatelessWidget {
  const StatusCardSection({super.key, required this.model});

  final StatusCardModel model;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: model.backgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(model.icon, color: model.accentColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.title,
                  style: PulseClockTextStyles.cardTitle.copyWith(
                    color: model.accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(model.subtitle, style: PulseClockTextStyles.cardSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryActionButtonSection extends StatefulWidget {
  const PrimaryActionButtonSection({
    super.key,
    required this.model,
    required this.onPressed,
  });

  final PrimaryActionModel model;
  final VoidCallback onPressed;

  @override
  State<PrimaryActionButtonSection> createState() =>
      _PrimaryActionButtonSectionState();
}

class _PrimaryActionButtonSectionState
    extends State<PrimaryActionButtonSection> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle baseStyle = ElevatedButton.styleFrom(
      foregroundColor: widget.model.foregroundColor,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PulseClockDimensions.cardRadius),
        side: BorderSide(
          color: PulseClockColors.surface.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      textStyle: PulseClockTextStyles.primaryAction,
    );

    return SizedBox(
      width: double.infinity,
      child: MouseRegion(
        onEnter: (_) {
          if (!_isHovered) {
            setState(() {
              _isHovered = true;
            });
          }
        },
        onExit: (_) {
          if (_isHovered) {
            setState(() {
              _isHovered = false;
            });
          }
        },
        child: AnimatedScale(
          scale: _isHovered ? 1.012 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: ElevatedButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(widget.model.icon, size: 26),
            label: Text(
              widget.model.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: baseStyle.copyWith(
              backgroundColor: MaterialStateProperty.resolveWith((
                Set<MaterialState> states,
              ) {
                if (states.contains(MaterialState.hovered)) {
                  return _brightenColor(widget.model.backgroundColor, 0.06);
                }
                if (states.contains(MaterialState.pressed)) {
                  return _brightenColor(widget.model.backgroundColor, -0.03);
                }
                return widget.model.backgroundColor;
              }),
              elevation: MaterialStateProperty.resolveWith((
                Set<MaterialState> states,
              ) {
                if (states.contains(MaterialState.pressed)) {
                  return 6;
                }
                if (states.contains(MaterialState.hovered)) {
                  return 14;
                }
                return 10;
              }),
              shadowColor: MaterialStateProperty.all(const Color(0x5A000000)),
              overlayColor: MaterialStateProperty.resolveWith((
                Set<MaterialState> states,
              ) {
                if (states.contains(MaterialState.hovered)) {
                  return Colors.white.withOpacity(0.09);
                }
                if (states.contains(MaterialState.pressed)) {
                  return Colors.black.withOpacity(0.08);
                }
                return null;
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class SummaryCardsRow extends StatelessWidget {
  const SummaryCardsRow({
    super.key,
    required this.summary,
    required this.status,
  });

  final SummaryModel summary;
  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final String clockInLabel = status == AttendanceStatus.onDuty
        ? 'Clocked In'
        : 'Clock In';

    return Row(
      children: [
        Expanded(
          child: SummaryCard(label: clockInLabel, value: summary.punchIn),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SummaryCard(label: 'Clock Out', value: summary.punchOut),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SummaryCard(label: 'Work Hours', value: summary.workHours),
        ),
      ],
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: PulseClockTextStyles.summaryLabel),
            const SizedBox(height: 10),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: PulseClockTextStyles.summaryValue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContextualCardsSection extends StatelessWidget {
  const ContextualCardsSection({
    super.key,
    required this.status,
    required this.onRequestCorrection,
  });

  final AttendanceStatus status;
  final VoidCallback onRequestCorrection;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case AttendanceStatus.offDuty:
        return const SizedBox.shrink();
      case AttendanceStatus.onDuty:
        return const SizedBox.shrink();
      case AttendanceStatus.missedPunch:
        return SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.assignment_late_outlined,
                    color: PulseClockColors.statusMissedAccent,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Action Required',
                      style: PulseClockTextStyles.cardTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Submit a correction request for March 6, 2026',
                style: PulseClockTextStyles.cardSubtitle,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onRequestCorrection,
                style: TextButton.styleFrom(
                  foregroundColor: PulseClockColors.actionBlue,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Request Correction ->',
                  style: PulseClockTextStyles.contextAction,
                ),
              ),
            ],
          ),
        );
      case AttendanceStatus.correctionPending:
        return SurfaceCard(
          child: const Row(
            children: [
              Icon(
                Icons.pending_actions_outlined,
                color: PulseClockColors.statusPendingAccent,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Review',
                      style: PulseClockTextStyles.cardTitle,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Correction for March 5, 2026',
                      style: PulseClockTextStyles.cardSubtitle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case AttendanceStatus.onLeave:
        return SurfaceCard(
          child: const Column(
            children: [
              LeaveDetailRow(label: 'Leave Type', value: 'Annual Leave'),
              SizedBox(height: 12),
              LeaveDetailRow(label: 'Duration', value: 'Full Day'),
              SizedBox(height: 12),
              LeaveDetailRow(label: 'Balance Remaining', value: '12 days'),
            ],
          ),
        );
    }
  }
}

class PulseBottomNavigation extends StatelessWidget {
  const PulseBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: PulseClockColors.surface,
      selectedItemColor: PulseClockColors.navSelected,
      unselectedItemColor: PulseClockColors.navUnselected,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.access_time_outlined),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.description_outlined),
          label: 'Requests',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on_outlined),
          label: 'Profile',
        ),
      ],
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.color = PulseClockColors.surface,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(PulseClockDimensions.cardRadius),
        border: Border.all(color: PulseClockColors.cardBorder),
        boxShadow: PulseClockShadows.soft,
      ),
      child: child,
    );
  }
}

class LeaveDetailRow extends StatelessWidget {
  const LeaveDetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: PulseClockTextStyles.cardSubtitle)),
        Text(
          value,
          style: PulseClockTextStyles.cardSubtitle.copyWith(
            color: PulseClockColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class StatusCardModel {
  const StatusCardModel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color accentColor;
}

class PrimaryActionModel {
  const PrimaryActionModel({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}

class SummaryModel {
  const SummaryModel({
    required this.punchIn,
    required this.punchOut,
    required this.workHours,
  });

  final String punchIn;
  final String punchOut;
  final String workHours;
}

StatusCardModel _statusCardFor(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.offDuty:
      return const StatusCardModel(
        title: 'Off Duty',
        subtitle: 'Ready to start your workday',
        icon: Icons.access_time_outlined,
        backgroundColor: PulseClockColors.statusOffDutyBg,
        accentColor: PulseClockColors.statusOffDutyAccent,
      );
    case AttendanceStatus.onDuty:
      return const StatusCardModel(
        title: 'On Duty',
        subtitle: 'You clocked in at 09:15 AM',
        icon: Icons.check_circle_outline,
        backgroundColor: PulseClockColors.statusOnDutyBg,
        accentColor: PulseClockColors.statusOnDutyAccent,
      );
    case AttendanceStatus.missedPunch:
      return const StatusCardModel(
        title: 'Missed Punch',
        subtitle: 'You missed clocking out yesterday',
        icon: Icons.cancel_outlined,
        backgroundColor: PulseClockColors.statusMissedBg,
        accentColor: PulseClockColors.statusMissedAccent,
      );
    case AttendanceStatus.correctionPending:
      return const StatusCardModel(
        title: 'Correction Pending',
        subtitle: 'Your attendance correction is under review',
        icon: Icons.error_outline,
        backgroundColor: PulseClockColors.statusPendingBg,
        accentColor: PulseClockColors.statusPendingAccent,
      );
    case AttendanceStatus.onLeave:
      return const StatusCardModel(
        title: 'On Leave',
        subtitle: 'Annual Leave (Full Day)',
        icon: Icons.beach_access_outlined,
        backgroundColor: PulseClockColors.statusLeaveBg,
        accentColor: PulseClockColors.statusLeaveAccent,
      );
  }
}

PrimaryActionModel _primaryActionFor(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.offDuty:
      return const PrimaryActionModel(
        label: 'Clock In',
        icon: Icons.access_time_outlined,
        backgroundColor: PulseClockColors.actionBlue,
        foregroundColor: PulseClockColors.surface,
      );
    case AttendanceStatus.onDuty:
      return const PrimaryActionModel(
        label: 'Clock Out',
        icon: Icons.access_time_outlined,
        backgroundColor: PulseClockColors.actionRed,
        foregroundColor: PulseClockColors.surface,
      );
    case AttendanceStatus.missedPunch:
      return const PrimaryActionModel(
        label: 'Request Correction',
        icon: Icons.assignment_late_outlined,
        backgroundColor: PulseClockColors.actionBlue,
        foregroundColor: PulseClockColors.surface,
      );
    case AttendanceStatus.correctionPending:
      return const PrimaryActionModel(
        label: 'View Request',
        icon: Icons.visibility_outlined,
        backgroundColor: PulseClockColors.actionBlue,
        foregroundColor: PulseClockColors.surface,
      );
    case AttendanceStatus.onLeave:
      return const PrimaryActionModel(
        label: 'View Leave Details',
        icon: Icons.remove_red_eye_outlined,
        backgroundColor: PulseClockColors.actionBlue,
        foregroundColor: PulseClockColors.surface,
      );
  }
}

SummaryModel _summaryFor(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.offDuty:
      return const SummaryModel(
        punchIn: '--',
        punchOut: '--',
        workHours: '0h 0m',
      );
    case AttendanceStatus.onDuty:
      return const SummaryModel(
        punchIn: '19:15',
        punchOut: '--',
        workHours: '3h 42m',
      );
    case AttendanceStatus.missedPunch:
      return const SummaryModel(
        punchIn: '09:02 AM',
        punchOut: '--',
        workHours: '0h 0m',
      );
    case AttendanceStatus.correctionPending:
      return const SummaryModel(
        punchIn: '--',
        punchOut: '--',
        workHours: '0h 0m',
      );
    case AttendanceStatus.onLeave:
      return const SummaryModel(punchIn: '--', punchOut: '--', workHours: '--');
  }
}

String _weekdayName(DateTime now) {
  const List<String> weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return weekdayNames[now.weekday - 1];
}

String _dateLabel(DateTime now) {
  return '${_twoDigits(now.day)}-${_twoDigits(now.month)}-${now.year}';
}

String _timeLabel(DateTime now) {
  final int hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final String period = now.hour >= 12 ? 'PM' : 'AM';
  return '${_twoDigits(hour)}:${_twoDigits(now.minute)} $period';
}

Color _brightenColor(Color color, double delta) {
  final HSLColor hsl = HSLColor.fromColor(color);
  final double nextLightness = (hsl.lightness + delta).clamp(0.0, 1.0);
  return hsl.withLightness(nextLightness).toColor();
}

bool _hasContextualCard(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.offDuty:
    case AttendanceStatus.onDuty:
      return false;
    case AttendanceStatus.missedPunch:
    case AttendanceStatus.correctionPending:
    case AttendanceStatus.onLeave:
      return true;
  }
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
