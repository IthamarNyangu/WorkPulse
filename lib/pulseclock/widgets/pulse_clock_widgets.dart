import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';

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
              weekdayName(now),
              style: PulseClockTextStyles.weekdayOnBackground,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Text(
            dateLabel(now),
            style: PulseClockTextStyles.dateOnBackground,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: Text(
            timeLabel(now),
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
      borderRadius: 12,
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
                Text(
                  model.subtitle,
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    color: model.accentColor.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
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
    this.borderRadius = PulseClockDimensions.cardRadius,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
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

Color _brightenColor(Color color, double delta) {
  final HSLColor hsl = HSLColor.fromColor(color);
  final double nextLightness = (hsl.lightness + delta).clamp(0.0, 1.0);
  return hsl.withLightness(nextLightness).toColor();
}
