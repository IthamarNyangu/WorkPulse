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

class HistoryStatusBadge extends StatelessWidget {
  const HistoryStatusBadge({super.key, required this.status});

  final AttendanceRecordStatus status;

  @override
  Widget build(BuildContext context) {
    final _StatusBadgeStyle style = _styleForHistoryStatus(status);

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

class HistoryFilterChipBar<T> extends StatelessWidget {
  const HistoryFilterChipBar({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<T> items;
  final T selectedValue;
  final String Function(T item) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((T item) {
          final bool isSelected = item == selectedValue;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labelBuilder(item)),
              selected: isSelected,
              onSelected: (_) => onSelected(item),
              labelStyle: PulseClockTextStyles.cardSubtitle.copyWith(
                color: isSelected
                    ? PulseClockColors.surface
                    : PulseClockColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected
                    ? PulseClockColors.actionBlue
                    : PulseClockColors.cardBorder,
              ),
              selectedColor: PulseClockColors.actionBlue,
              backgroundColor: PulseClockColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              showCheckmark: false,
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class HistoryRecordCard extends StatelessWidget {
  const HistoryRecordCard({super.key, required this.record, this.onTap});

  final AttendanceRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SurfaceCard(
        borderRadius: 14,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel(record.date),
                        style: PulseClockTextStyles.cardTitle.copyWith(
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        weekdayName(record.date),
                        style: PulseClockTextStyles.cardSubtitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                HistoryStatusBadge(status: record.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HistoryMetricCell(
                    label: 'Clock In',
                    value: record.clockInTime,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HistoryMetricCell(
                    label: 'Clock Out',
                    value: record.clockOutTime,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HistoryMetricCell(
                    label: 'Work Hours',
                    value: record.workHours,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMetricCell extends StatelessWidget {
  const _HistoryMetricCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: PulseClockColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: PulseClockTextStyles.summaryLabel.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

_StatusBadgeStyle _styleForHistoryStatus(AttendanceRecordStatus status) {
  switch (status) {
    case AttendanceRecordStatus.completed:
      return const _StatusBadgeStyle(
        backgroundColor: Color(0x1F15803D),
        foregroundColor: Color(0xFF0F8A43),
      );
    case AttendanceRecordStatus.missedPunch:
      return const _StatusBadgeStyle(
        backgroundColor: Color(0x22C81E3A),
        foregroundColor: Color(0xFFC81E3A),
      );
    case AttendanceRecordStatus.correctionPending:
      return const _StatusBadgeStyle(
        backgroundColor: Color(0x22B45309),
        foregroundColor: Color(0xFFB45309),
      );
    case AttendanceRecordStatus.leavePending:
      return const _StatusBadgeStyle(
        backgroundColor: Color(0x228F5CF6),
        foregroundColor: Color(0xFF7C3AED),
      );
    case AttendanceRecordStatus.onLeave:
      return const _StatusBadgeStyle(
        backgroundColor: Color(0x226B21A8),
        foregroundColor: Color(0xFF6B21A8),
      );
    case AttendanceRecordStatus.absent:
      return const _StatusBadgeStyle(
        backgroundColor: Color(0x22B91C1C),
        foregroundColor: Color(0xFFB91C1C),
      );
  }
}

class _StatusBadgeStyle {
  const _StatusBadgeStyle({
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
}

Color _brightenColor(Color color, double delta) {
  final HSLColor hsl = HSLColor.fromColor(color);
  final double nextLightness = (hsl.lightness + delta).clamp(0.0, 1.0);
  return hsl.withLightness(nextLightness).toColor();
}
