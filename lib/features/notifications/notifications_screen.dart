import 'package:flutter/material.dart';
import 'package:pulseclock/features/attendance/clock/clock_confirmation_screen.dart';
import 'package:pulseclock/features/corrections/correction_details_screen.dart';
import 'package:pulseclock/features/corrections/correction_list_screen.dart';
import 'package:pulseclock/features/leave/leave_details_screen.dart';
import 'package:pulseclock/features/leave/leave_list_screen.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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

  Future<void> _openFromNotification(WorkPulseNotification notification) async {
    _store.markNotificationAsRead(notification.id);
    await _navigateToNotificationTarget(notification);
  }

  Future<void> _navigateToNotificationTarget(
    WorkPulseNotification notification,
  ) async {
    final NotificationNavigationTarget? target = notification.navigationTarget;
    if (target == null || !mounted) {
      return;
    }

    switch (target) {
      case NotificationNavigationTarget.clockInConfirmation:
        await _openClockConfirmation(mode: ClockActionMode.clockIn);
        return;
      case NotificationNavigationTarget.clockOutConfirmation:
        await _openClockConfirmation(mode: ClockActionMode.clockOut);
        return;
      case NotificationNavigationTarget.correctionList:
        await Navigator.of(context).push<void>(
          PageRouteBuilder<void>(
            pageBuilder:
                (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondaryAnimation,
                ) {
                  return const CorrectionListScreen();
                },
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        return;
      case NotificationNavigationTarget.correctionDetails:
        await Navigator.of(context).push<void>(
          PageRouteBuilder<void>(
            pageBuilder:
                (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondaryAnimation,
                ) {
                  return CorrectionDetailsScreen(
                    initialRequestId: notification.correctionRequestId,
                  );
                },
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        return;
      case NotificationNavigationTarget.leaveList:
        await Navigator.of(context).push<void>(
          PageRouteBuilder<void>(
            pageBuilder:
                (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondaryAnimation,
                ) {
                  return const LeaveListScreen();
                },
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        return;
      case NotificationNavigationTarget.leaveDetails:
        if (notification.leaveRequestId == null) {
          await Navigator.of(context).push<void>(
            PageRouteBuilder<void>(
              pageBuilder:
                  (
                    BuildContext context,
                    Animation<double> animation,
                    Animation<double> secondaryAnimation,
                  ) {
                    return const LeaveListScreen();
                  },
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
          return;
        }
        await Navigator.of(context).push<void>(
          PageRouteBuilder<void>(
            pageBuilder:
                (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondaryAnimation,
                ) {
                  return LeaveDetailsScreen(requestId: notification.leaveRequestId!);
                },
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        return;
    }
  }

  Future<void> _openClockConfirmation({required ClockActionMode mode}) async {
    final ClockConfirmationResult? result = await Navigator.of(context)
        .push<ClockConfirmationResult>(
          MaterialPageRoute<ClockConfirmationResult>(
            builder: (BuildContext context) {
              return ClockConfirmationScreen(mode: mode);
            },
          ),
        );
    if (!mounted || result == null) {
      return;
    }
    _store.applyClockConfirmationResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final List<WorkPulseNotification> notifications = _store.notifications;
    final List<_NotificationDateGroup> groupedNotifications =
        _groupNotificationsByDate(notifications);

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: TextButton(
                  onPressed: _store.clearAllNotifications,
                  style: TextButton.styleFrom(
                    foregroundColor: PulseClockColors.actionBlue,
                    backgroundColor: const Color(0x142563EB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Clear All'),
                ),
              ),
            ),
        ],
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
              24,
            ),
            child: notifications.isEmpty
                ? const _NoNotificationState()
                : ListView(
                    children: [
                      for (final _NotificationDateGroup group
                          in groupedNotifications) ...<Widget>[
                        Text(
                          group.label,
                          style: PulseClockTextStyles.cardSubtitle.copyWith(
                            color: PulseClockColors.onBackgroundPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (int index = 0; index < group.notifications.length; index++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == group.notifications.length - 1 ? 18 : 8,
                            ),
                            child: _NotificationCard(
                              notification: group.notifications[index],
                              onTap: () => _openFromNotification(
                                group.notifications[index],
                              ),
                              onAction: group.notifications[index].actionLabel == null
                                  ? null
                                  : () => _openFromNotification(
                                        group.notifications[index],
                                      ),
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    this.onAction,
  });

  final WorkPulseNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final _NotificationStyle style = _styleForType(notification.type);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SurfaceCard(
        borderRadius: 14,
        padding: EdgeInsets.zero,
        color: notification.isRead
            ? const Color(0xFFF8FAFC)
            : PulseClockColors.surface,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 96,
                color: style.indicatorColor,
              ),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 96),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PulseClockTextStyles.cardSubtitle.copyWith(
                                  color: PulseClockColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: PulseClockColors.actionBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PulseClockTextStyles.cardSubtitle.copyWith(
                            fontSize: 13,
                            height: 1.25,
                            color: notification.isRead
                                ? PulseClockColors.textSecondary.withOpacity(0.86)
                                : PulseClockColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              timeLabel(notification.timestamp),
                              style: PulseClockTextStyles.cardSubtitle.copyWith(
                                fontSize: 11,
                                color: PulseClockColors.textSecondary.withOpacity(0.78),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (notification.actionLabel != null)
                              TextButton(
                                onPressed: onAction,
                                style: TextButton.styleFrom(
                                  foregroundColor: style.indicatorColor,
                                  backgroundColor: style.backgroundTint,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  textStyle: PulseClockTextStyles.cardSubtitle.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: Text(notification.actionLabel!),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoNotificationState extends StatelessWidget {
  const _NoNotificationState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SurfaceCard(
        child: Row(
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: PulseClockColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No reminders available right now.',
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

class _NotificationDateGroup {
  const _NotificationDateGroup({
    required this.label,
    required this.notifications,
  });

  final String label;
  final List<WorkPulseNotification> notifications;
}

class _NotificationStyle {
  const _NotificationStyle({
    required this.indicatorColor,
    required this.backgroundTint,
  });

  final Color indicatorColor;
  final Color backgroundTint;
}

List<_NotificationDateGroup> _groupNotificationsByDate(
  List<WorkPulseNotification> notifications,
) {
  final Map<String, List<WorkPulseNotification>> grouped =
      <String, List<WorkPulseNotification>>{};

  for (final WorkPulseNotification notification in notifications) {
    final String key = dateLabel(notification.timestamp);
    grouped.putIfAbsent(key, () => <WorkPulseNotification>[]);
    grouped[key]!.add(notification);
  }

  return grouped.entries
      .map(
        (MapEntry<String, List<WorkPulseNotification>> entry) =>
            _NotificationDateGroup(
              label: entry.key,
              notifications: entry.value,
            ),
      )
      .toList(growable: false);
}

_NotificationStyle _styleForType(WorkPulseNotificationType type) {
  switch (type) {
    case WorkPulseNotificationType.clockInReminder:
      return const _NotificationStyle(
        indicatorColor: PulseClockColors.actionBlue,
        backgroundTint: Color(0x142563EB),
      );
    case WorkPulseNotificationType.clockOutReminder:
      return const _NotificationStyle(
        indicatorColor: Color(0xFFF97316),
        backgroundTint: Color(0x14F97316),
      );
    case WorkPulseNotificationType.missedPunchReminder:
      return const _NotificationStyle(
        indicatorColor: Color(0xFFC81E3A),
        backgroundTint: Color(0x14C81E3A),
      );
    case WorkPulseNotificationType.leaveUpdate:
      return const _NotificationStyle(
        indicatorColor: Color(0xFF0F8A43),
        backgroundTint: Color(0x1415803D),
      );
    case WorkPulseNotificationType.generalInfo:
      return const _NotificationStyle(
        indicatorColor: Color(0xFF475569),
        backgroundTint: Color(0x14475569),
      );
  }
}
