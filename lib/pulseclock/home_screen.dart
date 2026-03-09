import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/styles.dart';

enum AttendanceStatus { offDuty, onDuty }

enum RequestEntryType { missedPunch, correctionPending, leaveDetails }

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
      _status = _status == AttendanceStatus.offDuty
          ? AttendanceStatus.onDuty
          : AttendanceStatus.offDuty;
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

  Widget _buildTabContent() {
    switch (_selectedNavIndex) {
      case 0:
        return HomeTabContent(
          now: _now,
          status: _status,
          onPrimaryActionPressed: _onPrimaryActionPressed,
        );
      case 1:
        return const PlaceholderTab(
          title: 'History',
          message: 'Attendance history will appear here.',
          icon: Icons.calendar_today_outlined,
        );
      case 2:
        return RequestsTab(onSelect: _openRequestDetail);
      case 3:
        return const PlaceholderTab(
          title: 'Profile',
          message: 'Profile settings will appear here.',
          icon: Icons.location_on_outlined,
        );
      default:
        return HomeTabContent(
          now: _now,
          status: _status,
          onPrimaryActionPressed: _onPrimaryActionPressed,
        );
    }
  }

  Widget _buildBackgroundLayer(BuildContext context) {
    const double backgroundOpacity = 0.12;

    if (_selectedNavIndex == 0) {
      return Positioned(
        top: -48,
        right: -170,
        child: IgnorePointer(
          child: Opacity(
            opacity: backgroundOpacity,
            child: Image.asset(
              'assets/images/workpulse-bg.png',
              width: MediaQuery.sizeOf(context).width * 1.45,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: backgroundOpacity,
          child: Image.asset(
            'assets/images/workpulse-bg.png',
            fit: BoxFit.cover,
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
    required this.onPrimaryActionPressed,
  });

  final DateTime now;
  final AttendanceStatus status;
  final VoidCallback onPrimaryActionPressed;

  @override
  Widget build(BuildContext context) {
    final StatusCardModel statusCard = _statusCardFor(status);
    final PrimaryActionModel primaryAction = _primaryActionFor(status);
    final SummaryModel summary = _summaryFor(status);

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
          const Center(
            child: Text(
              'App Version:demo',
              style: TextStyle(
                fontSize: 11,
                color: PulseClockColors.onBackgroundSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RequestsTab extends StatelessWidget {
  const RequestsTab({super.key, required this.onSelect});

  final ValueChanged<RequestEntryType> onSelect;

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
          const Text('Requests', style: PulseClockTextStyles.headerTitle),
          const SizedBox(height: 6),
          const Text(
            'Select an item to view its details.',
            style: PulseClockTextStyles.headerSubtitle,
          ),
          const SizedBox(height: 20),
          RequestOptionCard(
            type: RequestEntryType.missedPunch,
            onTap: onSelect,
          ),
          const SizedBox(height: 12),
          RequestOptionCard(
            type: RequestEntryType.correctionPending,
            onTap: onSelect,
          ),
          const SizedBox(height: 12),
          RequestOptionCard(
            type: RequestEntryType.leaveDetails,
            onTap: onSelect,
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
  const RequestOptionCard({super.key, required this.type, required this.onTap});

  final RequestEntryType type;
  final ValueChanged<RequestEntryType> onTap;

  @override
  Widget build(BuildContext context) {
    final RequestEntryModel model = _requestEntryFor(type);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(type),
      child: SurfaceCard(
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
                    model.subtitle,
                    style: PulseClockTextStyles.cardSubtitle,
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

class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.type});

  final RequestEntryType type;

  @override
  Widget build(BuildContext context) {
    final RequestDetailModel detail = _requestDetailFor(type);

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: Text(detail.title),
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
                StatusCardSection(model: detail.statusCard),
                const SizedBox(height: 16),
                SurfaceCard(child: RequestDetailBody(type: type)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RequestDetailBody extends StatelessWidget {
  const RequestDetailBody({super.key, required this.type});

  final RequestEntryType type;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case RequestEntryType.missedPunch:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DetailInfoRow(label: 'Issue Date', value: 'March 6, 2026'),
            const SizedBox(height: 12),
            const Text(
              'Submit a correction request with your actual clock-out time.',
              style: PulseClockTextStyles.cardSubtitle,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Correction request flow coming soon.'),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: PulseClockColors.actionBlue,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Submit Correction Request',
                style: PulseClockTextStyles.contextAction,
              ),
            ),
          ],
        );
      case RequestEntryType.correctionPending:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailInfoRow(label: 'Request Date', value: 'March 5, 2026'),
            SizedBox(height: 12),
            DetailInfoRow(label: 'Status', value: 'Pending Review'),
            SizedBox(height: 12),
            Text(
              'Your attendance correction is currently with your manager.',
              style: PulseClockTextStyles.cardSubtitle,
            ),
          ],
        );
      case RequestEntryType.leaveDetails:
        return const Column(
          children: [
            LeaveDetailRow(label: 'Leave Type', value: 'Annual Leave'),
            SizedBox(height: 12),
            LeaveDetailRow(label: 'Duration', value: 'Full Day'),
            SizedBox(height: 12),
            LeaveDetailRow(label: 'Balance Remaining', value: '12 days'),
          ],
        );
    }
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
        const Text('WorkPulse', style: PulseClockTextStyles.headerTitle),
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

class StatusCardSection extends StatelessWidget {
  const StatusCardSection({super.key, required this.model});

  final StatusCardModel model;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      color: model.backgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              backgroundColor: WidgetStateProperty.resolveWith((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.hovered)) {
                  return _brightenColor(widget.model.backgroundColor, 0.06);
                }
                if (states.contains(WidgetState.pressed)) {
                  return _brightenColor(widget.model.backgroundColor, -0.03);
                }
                return widget.model.backgroundColor;
              }),
              elevation: WidgetStateProperty.resolveWith((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return 6;
                }
                if (states.contains(WidgetState.hovered)) {
                  return 14;
                }
                return 10;
              }),
              shadowColor: WidgetStateProperty.all(const Color(0x5A000000)),
              overlayColor: WidgetStateProperty.resolveWith((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withOpacity(0.09);
                }
                if (states.contains(WidgetState.pressed)) {
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
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: PulseClockColors.surface,
        selectedItemColor: PulseClockColors.navSelected,
        unselectedItemColor: PulseClockColors.navUnselected,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        enableFeedback: false,
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
      ),
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

class DetailInfoRow extends StatelessWidget {
  const DetailInfoRow({super.key, required this.label, required this.value});

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

class RequestEntryModel {
  const RequestEntryModel({
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

class RequestDetailModel {
  const RequestDetailModel({required this.title, required this.statusCard});

  final String title;
  final StatusCardModel statusCard;
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
    default:
      return const StatusCardModel(
        title: 'Off Duty',
        subtitle: 'Ready to start your workday',
        icon: Icons.access_time_outlined,
        backgroundColor: PulseClockColors.statusOffDutyBg,
        accentColor: PulseClockColors.statusOffDutyAccent,
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
    default:
      return const PrimaryActionModel(
        label: 'Clock In',
        icon: Icons.access_time_outlined,
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
    default:
      return const SummaryModel(
        punchIn: '--',
        punchOut: '--',
        workHours: '0h 0m',
      );
  }
}

RequestEntryModel _requestEntryFor(RequestEntryType type) {
  switch (type) {
    case RequestEntryType.missedPunch:
      return const RequestEntryModel(
        title: 'Missed Punch',
        subtitle: 'You missed clocking out yesterday',
        icon: Icons.cancel_outlined,
        backgroundColor: PulseClockColors.statusMissedBg,
        accentColor: PulseClockColors.statusMissedAccent,
      );
    case RequestEntryType.correctionPending:
      return const RequestEntryModel(
        title: 'Correction Pending',
        subtitle: 'Your attendance correction is under review',
        icon: Icons.pending_actions_outlined,
        backgroundColor: PulseClockColors.statusPendingBg,
        accentColor: PulseClockColors.statusPendingAccent,
      );
    case RequestEntryType.leaveDetails:
      return const RequestEntryModel(
        title: 'Leave Details',
        subtitle: 'Annual Leave (Full Day)',
        icon: Icons.beach_access_outlined,
        backgroundColor: PulseClockColors.statusLeaveBg,
        accentColor: PulseClockColors.statusLeaveAccent,
      );
    default:
      return const RequestEntryModel(
        title: 'Missed Punch',
        subtitle: 'You missed clocking out yesterday',
        icon: Icons.cancel_outlined,
        backgroundColor: PulseClockColors.statusMissedBg,
        accentColor: PulseClockColors.statusMissedAccent,
      );
  }
}

RequestDetailModel _requestDetailFor(RequestEntryType type) {
  switch (type) {
    case RequestEntryType.missedPunch:
      return const RequestDetailModel(
        title: 'Missed Punch',
        statusCard: StatusCardModel(
          title: 'Action Required',
          subtitle: 'Submit a correction request for March 6, 2026',
          icon: Icons.assignment_late_outlined,
          backgroundColor: PulseClockColors.statusMissedBg,
          accentColor: PulseClockColors.statusMissedAccent,
        ),
      );
    case RequestEntryType.correctionPending:
      return const RequestDetailModel(
        title: 'Correction Pending',
        statusCard: StatusCardModel(
          title: 'Pending Review',
          subtitle: 'Correction for March 5, 2026',
          icon: Icons.pending_actions_outlined,
          backgroundColor: PulseClockColors.statusPendingBg,
          accentColor: PulseClockColors.statusPendingAccent,
        ),
      );
    case RequestEntryType.leaveDetails:
      return const RequestDetailModel(
        title: 'Leave Details',
        statusCard: StatusCardModel(
          title: 'On Leave',
          subtitle: 'Annual Leave (Full Day)',
          icon: Icons.beach_access_outlined,
          backgroundColor: PulseClockColors.statusLeaveBg,
          accentColor: PulseClockColors.statusLeaveAccent,
        ),
      );
    default:
      return const RequestDetailModel(
        title: 'Missed Punch',
        statusCard: StatusCardModel(
          title: 'Action Required',
          subtitle: 'Submit a correction request for March 6, 2026',
          icon: Icons.assignment_late_outlined,
          backgroundColor: PulseClockColors.statusMissedBg,
          accentColor: PulseClockColors.statusMissedAccent,
        ),
      );
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
  const List<String> monthAbbreviations = <String>[
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
  return '${_twoDigits(now.day)} ${monthAbbreviations[now.month - 1]} ${now.year}';
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

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
