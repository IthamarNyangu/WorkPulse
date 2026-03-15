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
    final int unreadCount = _store.unreadNotificationCount;

    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _store.markAllNotificationsAsRead,
              child: Text(
                'Mark All Read',
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  color: PulseClockColors.actionBlue,
                  fontWeight: FontWeight.w700,
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
              28,
            ),
            child: notifications.isEmpty
                ? const _NoNotificationState()
                : ListView.separated(
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final WorkPulseNotification notification =
                          notifications[index];
                      return _NotificationCard(
                        notification: notification,
                        onTap: () => _openFromNotification(notification),
                        onAction: notification.actionLabel == null
                            ? null
                            : () => _openFromNotification(notification),
                      );
                    },
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
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        color: notification.isRead ? const Color(0xFFF9FAFC) : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: style.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    style.icon,
                    size: 20,
                    color: style.foregroundColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: PulseClockTextStyles.cardTitle.copyWith(
                                fontSize: 18,
                                color: PulseClockColors.textPrimary,
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
                      const SizedBox(height: 2),
                      Text(
                        notification.message,
                        style: PulseClockTextStyles.cardSubtitle.copyWith(
                          fontSize: 14,
                          color: notification.isRead
                              ? PulseClockColors.textSecondary.withOpacity(0.88)
                              : PulseClockColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _timestampLabel(notification.timestamp),
                        style: PulseClockTextStyles.cardSubtitle.copyWith(
                          fontSize: 12,
                          color: PulseClockColors.textSecondary.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (notification.actionLabel != null) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onAction,
                    icon: Icon(
                      style.icon,
                      size: 16,
                      color: PulseClockColors.actionBlue,
                    ),
                    label: Text(
                      notification.actionLabel!,
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        color: PulseClockColors.actionBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
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

class _NotificationStyle {
  const _NotificationStyle({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}

_NotificationStyle _styleForType(WorkPulseNotificationType type) {
  switch (type) {
    case WorkPulseNotificationType.clockInReminder:
      return const _NotificationStyle(
        icon: Icons.login_rounded,
        backgroundColor: Color(0x1F2563EB),
        foregroundColor: PulseClockColors.actionBlue,
      );
    case WorkPulseNotificationType.clockOutReminder:
      return const _NotificationStyle(
        icon: Icons.logout_rounded,
        backgroundColor: Color(0x22B91C1C),
        foregroundColor: Color(0xFFB91C1C),
      );
    case WorkPulseNotificationType.missedPunchReminder:
      return const _NotificationStyle(
        icon: Icons.warning_amber_rounded,
        backgroundColor: Color(0x22C81E3A),
        foregroundColor: Color(0xFFC81E3A),
      );
    case WorkPulseNotificationType.leaveUpdate:
      return const _NotificationStyle(
        icon: Icons.event_note_rounded,
        backgroundColor: Color(0x226B21A8),
        foregroundColor: Color(0xFF6B21A8),
      );
    case WorkPulseNotificationType.generalInfo:
      return const _NotificationStyle(
        icon: Icons.info_outline_rounded,
        backgroundColor: Color(0x1F64748B),
        foregroundColor: Color(0xFF334155),
      );
  }
}

String _timestampLabel(DateTime timestamp) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime tsDay = DateTime(
    timestamp.year,
    timestamp.month,
    timestamp.day,
  );
  final String time = timeLabel(timestamp);
  if (tsDay == today) {
    return 'Today, $time';
  }
  return '${dateLabel(timestamp)}, $time';
}
