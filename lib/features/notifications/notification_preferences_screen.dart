import 'package:flutter/material.dart';
import 'package:pulseclock/features/notifications/data/local_notification_service.dart';
import 'package:pulseclock/features/notifications/data/notification_preferences_service.dart';
import 'package:pulseclock/features/notifications/workpulse_reminder_controller.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen>
    with WidgetsBindingObserver {
  final NotificationPreferencesService _service =
      NotificationPreferencesService();
  final WorkPulseReminderController _reminders =
      WorkPulseReminderController.instance;
  final WorkPulseLocalNotificationService _localNotifications =
      WorkPulseLocalNotificationService.instance;

  NotificationPreferences? _preferences;
  bool _saving = false;
  bool _osNotificationsEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reminders.addListener(_onReminderChanged);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminders.removeListener(_onReminderChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDeviceStatus();
      _reminders.refreshBackgroundGeofences();
    }
  }

  void _onReminderChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    try {
      await _localNotifications.initialize();
      final NotificationPreferences preferences = await _service.fetch();
      final bool enabled = await _localNotifications.notificationsEnabled();
      if (!mounted) {
        return;
      }
      setState(() {
        _preferences = preferences;
        _osNotificationsEnabled = enabled;
        _error = null;
      });
      await _reminders.refreshPreferences();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load notification preferences.';
        });
      }
    }
  }

  Future<void> _refreshDeviceStatus() async {
    final bool enabled = await _localNotifications.notificationsEnabled();
    if (mounted) {
      setState(() => _osNotificationsEnabled = enabled);
    }
  }

  Future<void> _save(NotificationPreferences next) async {
    if (_saving) {
      return;
    }
    final NotificationPreferences previous = _preferences!;
    setState(() {
      _saving = true;
      _preferences = next;
      _error = null;
    });
    try {
      final NotificationPreferences saved = await _service.save(next);
      if (next.pushEnabled && !previous.pushEnabled) {
        await _localNotifications.requestPermission();
      }
      if (next.smartLocationEnabled != previous.smartLocationEnabled) {
        await _reminders.refreshBackgroundGeofences();
      } else {
        await _reminders.refreshPreferences();
      }
      await _refreshDeviceStatus();
      if (mounted) {
        setState(() => _preferences = saved);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _preferences = previous;
          _error = 'The preference could not be saved. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _enableSmartLocation(bool enabled) async {
    final NotificationPreferences current = _preferences!;
    if (!enabled) {
      await _save(current.copyWith(smartLocationEnabled: false));
      return;
    }

    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: PulseClockColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enable Smart Location Reminders?'),
        content: const Text(
          'WorkPulse will use approved office geofences to remind you after '
          'you remain at an office for 3 minutes. Android background location '
          'permission is required. WorkPulse does not save a continuous '
          'location trail.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _save(current.copyWith(smartLocationEnabled: true));
    }
  }

  String get _smartLocationStatus {
    if (_preferences?.smartLocationEnabled != true) {
      return 'Off. No background geofences are registered.';
    }
    if (_reminders.backgroundLocationPermissionRequired) {
      return 'Android background location permission is required.';
    }
    if (_reminders.backgroundLocationReady) {
      final int offices = _reminders.registeredBackgroundOffices;
      return 'Active for $offices approved ${offices == 1 ? 'office' : 'offices'}.';
    }
    return 'Preparing smart location reminders...';
  }

  @override
  Widget build(BuildContext context) {
    final NotificationPreferences? preferences = _preferences;
    return Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              PulseClockColors.appBackground,
              PulseClockColors.appBackgroundDeep,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: preferences == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator(color: Colors.white)
                      : _LoadError(message: _error!, onRetry: _load),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Text(
                        'Choose how WorkPulse reminds you.',
                        style: PulseClockTextStyles.headerSubtitle,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SurfaceCard(
                        padding: EdgeInsets.zero,
                        borderRadius: 14,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                          _PreferenceSwitch(
                            icon: Icons.schedule_rounded,
                            title: 'Basic Attendance Reminders',
                            subtitle:
                                'Scheduled Clock In, Clock Out, and missed attendance reminders.',
                            value: preferences.basicAttendanceEnabled,
                            enabled: !_saving,
                            onChanged: (bool value) => _save(
                              preferences.copyWith(
                                basicAttendanceEnabled: value,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _PreferenceSwitch(
                            icon: Icons.location_on_outlined,
                            title: 'Smart Location Reminders',
                            subtitle: _smartLocationStatus,
                            value: preferences.smartLocationEnabled,
                            enabled: !_saving,
                            onChanged: _enableSmartLocation,
                          ),
                          if (preferences.smartLocationEnabled &&
                              _reminders
                                  .backgroundLocationPermissionRequired) ...<
                            Widget
                          >[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(60, 0, 16, 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                  onPressed:
                                      _reminders.openBackgroundLocationSettings,
                                  child: const Text('Open Android Settings'),
                                ),
                              ),
                            ),
                          ],
                          const Divider(height: 1),
                          _PreferenceSwitch(
                            icon: Icons.task_alt_rounded,
                            title: 'Request Updates',
                            subtitle:
                                'Leave and attendance correction approval updates.',
                            value: preferences.requestUpdatesEnabled,
                            enabled: !_saving,
                            onChanged: (bool value) => _save(
                              preferences.copyWith(
                                requestUpdatesEnabled: value,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _PreferenceSwitch(
                            icon: Icons.notifications_outlined,
                            title: 'Push Notifications',
                            subtitle: preferences.pushEnabled
                                ? (_osNotificationsEnabled
                                      ? 'Push delivery is enabled, and Android allows notifications on this device.'
                                      : 'Push delivery is enabled, but Android blocks notifications on this device.')
                                : 'Off for your account. Reminders still appear under the WorkPulse bell.',
                            value: preferences.pushEnabled,
                            enabled: !_saving,
                            onChanged: (bool value) =>
                                _save(preferences.copyWith(pushEnabled: value)),
                          ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: PulseClockColors.onBackgroundPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: PulseClockColors.actionBlueSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: PulseClockColors.actionBlue),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: PulseClockColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: PulseClockTextStyles.cardSubtitle.copyWith(fontSize: 13),
        ),
      ),
      value: value,
      activeTrackColor: PulseClockColors.actionBlue,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
