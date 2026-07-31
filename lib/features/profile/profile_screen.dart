import 'package:flutter/material.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/features/employees/employee_list_screen.dart';
import 'package:pulseclock/features/geofence/presentation/geofence_exception_review_screen.dart';
import 'package:pulseclock/features/notifications/notifications_screen.dart';
import 'package:pulseclock/features/office_locations/office_locations_admin_screen.dart';
import 'package:pulseclock/features/supervisor/attendance/presentation/supervisor_attendance_dashboard_screen.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Set<String> _teamRoles = <String>{'supervisor', 'hr', 'admin'};
  static const Set<String> _organisationManagerRoles = <String>{'hr', 'admin'};

  String _employeeName = 'WorkPulse User';
  String _employeeId = '--';
  String _employeeRole = 'employee';
  String? _employeeDepartment;
  String? _employeeJobTitle;
  bool _isLoggingOut = false;

  bool get _canViewTeamTools => _teamRoles.contains(_employeeRole);

  bool get _canManageOrganisation =>
      _organisationManagerRoles.contains(_employeeRole);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!SupabaseBootstrap.isInitialized) {
      return;
    }

    try {
      final WorkPulseUserProfile? profile = await AuthService()
          .fetchCurrentProfile();
      if (!mounted || profile == null) {
        return;
      }
      setState(() {
        _employeeName = profile.fullName;
        _employeeId = profile.employeeId;
        _employeeRole = profile.role;
        _employeeDepartment = profile.department;
        _employeeJobTitle = profile.jobTitle;
      });
    } catch (_) {
      // Keep existing mock values if the backend profile is unavailable.
    }
  }

  Future<void> _openNotifications(BuildContext context) async {
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

  Future<void> _openOfficeLocations(BuildContext context) async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return const OfficeLocationsAdminScreen();
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _openGeofenceReview(BuildContext context) async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return const GeofenceExceptionReviewScreen();
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _openAttendanceDashboard(BuildContext context) async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return const SupervisorAttendanceDashboardScreen();
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _openEmployees(BuildContext context) async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return const EmployeeListScreen();
            },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _showPlaceholderDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFCFDFE),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            title,
            style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
          ),
          content: Text(
            message,
            style: PulseClockTextStyles.cardSubtitle.copyWith(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRateUsModal(BuildContext context) async {
    final BuildContext parentContext = context;
    final TextEditingController feedbackController = TextEditingController();
    int selectedRating = 0;

    await showDialog<void>(
      context: parentContext,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final bool showFeedback = selectedRating > 0 && selectedRating < 3;
            final bool showThankYou = selectedRating >= 4;

            return Dialog(
              backgroundColor: const Color(0xFFFCFDFE),
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rate WorkPulse',
                        style: PulseClockTextStyles.cardTitle.copyWith(
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'How is your experience so far?',
                        style: PulseClockTextStyles.cardSubtitle,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(5, (int index) {
                          final int starValue = index + 1;
                          final bool isSelected = starValue <= selectedRating;
                          return IconButton(
                            onPressed: () {
                              setModalState(() {
                                selectedRating = starValue;
                              });
                            },
                            icon: Icon(
                              isSelected
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isSelected
                                  ? const Color(0xFFF59E0B)
                                  : PulseClockColors.textSecondary.withOpacity(
                                      0.55,
                                    ),
                              size: 32,
                            ),
                          );
                        }),
                      ),
                      if (showThankYou) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x1415803D),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Thanks for the high rating. We are glad WorkPulse is helping.',
                            style: PulseClockTextStyles.cardSubtitle.copyWith(
                              color: const Color(0xFF0F8A43),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (showFeedback) ...<Widget>[
                        const SizedBox(height: 12),
                        TextField(
                          controller: feedbackController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Optional feedback',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: PulseClockColors.surfaceMuted,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: PulseClockColors.cardBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: PulseClockColors.cardBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: PulseClockColors.actionBlue,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedRating == 0
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(
                                    parentContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        selectedRating >= 4
                                            ? 'Thanks for rating WorkPulse.'
                                            : 'Thanks for the feedback. We will use it to improve WorkPulse.',
                                      ),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PulseClockColors.actionBlue,
                            foregroundColor: PulseClockColors.surface,
                            disabledBackgroundColor: PulseClockColors.actionBlue
                                .withOpacity(0.45),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: PulseClockTextStyles.contextAction
                                .copyWith(
                                  color: PulseClockColors.surface,
                                  fontSize: 16,
                                ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                PulseClockDimensions.cardRadius,
                              ),
                            ),
                          ),
                          child: const Text('Submit Rating'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    feedbackController.dispose();
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    if (!SupabaseBootstrap.isInitialized) {
      await _showPlaceholderDialog(
        context,
        title: 'Logout',
        message: 'Supabase authentication is not enabled in this run.',
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFCFDFE),
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 44,
            vertical: 24,
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            'Log Out',
            style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
          ),
          content: Text(
            'Are you sure you want to log out of WorkPulse?',
            style: PulseClockTextStyles.cardSubtitle.copyWith(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: PulseClockColors.actionBlue,
                textStyle: PulseClockTextStyles.cardSubtitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await AuthService().logout();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

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
          Text(
            'Profile',
            style: PulseClockTextStyles.headerTitle.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 18),
          _ProfileHeaderCard(
            employeeName: _employeeName,
            employeeId: _employeeId,
            department: _employeeDepartment,
            jobTitle: _employeeJobTitle,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: [
                if (_canViewTeamTools) ...<Widget>[
                  _SectionHeader(
                    title: _canManageOrganisation ? 'Administration' : 'Team',
                  ),
                  const SizedBox(height: 8),
                  _ProfileSectionCard(
                    items: [
                      _ProfileActionItem(
                        icon: Icons.people_outline_rounded,
                        title: 'Employees',
                        onTap: () => _openEmployees(context),
                      ),
                      _ProfileActionItem(
                        icon: Icons.dashboard_outlined,
                        title: 'Attendance Dashboard',
                        onTap: () => _openAttendanceDashboard(context),
                      ),
                      if (_canManageOrganisation)
                        _ProfileActionItem(
                          icon: Icons.business_outlined,
                          title: 'Office Locations',
                          onTap: () => _openOfficeLocations(context),
                        ),
                      if (_canManageOrganisation)
                        _ProfileActionItem(
                          icon: Icons.gpp_maybe_outlined,
                          title: 'Geofence Review',
                          onTap: () => _openGeofenceReview(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                _SectionHeader(title: 'Preferences'),
                const SizedBox(height: 8),
                _ProfileSectionCard(
                  items: [
                    _ProfileActionItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () => _showPlaceholderDialog(
                        context,
                        title: 'Settings',
                        message:
                            'Settings controls will be connected in a future update.',
                      ),
                    ),
                    _ProfileActionItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Manage Notifications',
                      onTap: () => _openNotifications(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionHeader(title: 'Support'),
                const SizedBox(height: 8),
                _ProfileSectionCard(
                  items: [
                    _ProfileActionItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      onTap: () => _showPlaceholderDialog(
                        context,
                        title: 'Help & Support',
                        message: 'Support tools will be connected here soon.',
                      ),
                    ),
                    _ProfileActionItem(
                      icon: Icons.quiz_outlined,
                      title: 'FAQ',
                      onTap: () => _showPlaceholderDialog(
                        context,
                        title: 'FAQ',
                        message: 'FAQ content is a placeholder for now.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionHeader(title: 'About'),
                const SizedBox(height: 8),
                _ProfileSectionCard(
                  items: [
                    _ProfileActionItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About WorkPulse',
                      onTap: () => _showPlaceholderDialog(
                        context,
                        title: 'About WorkPulse',
                        message:
                            'WorkPulse helps teams manage attendance, requests, and reminders.',
                      ),
                    ),
                    _ProfileActionItem(
                      icon: Icons.article_outlined,
                      title: 'Terms & Conditions',
                      onTap: () => _showPlaceholderDialog(
                        context,
                        title: 'Terms & Conditions',
                        message: 'Terms content will be added later.',
                      ),
                    ),
                    _ProfileActionItem(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy Policy',
                      onTap: () => _showPlaceholderDialog(
                        context,
                        title: 'Privacy Policy',
                        message: 'Privacy policy content will be added later.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionHeader(title: 'Feedback'),
                const SizedBox(height: 8),
                _ProfileSectionCard(
                  items: [
                    _ProfileActionItem(
                      icon: Icons.star_outline_rounded,
                      title: 'Rate Us',
                      onTap: () => _showRateUsModal(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoggingOut ? null : _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                      backgroundColor: const Color(0xFFFDF4F4),
                      side: const BorderSide(color: Color(0xFFF3B6B6)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: PulseClockTextStyles.contextAction.copyWith(
                        color: const Color(0xFFB42318),
                        fontSize: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          PulseClockDimensions.cardRadius,
                        ),
                      ),
                    ),
                    child: _isLoggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFB42318),
                              ),
                            ),
                          )
                        : const Text('Logout'),
                  ),
                ),
                const SizedBox(height: 16),
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
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.employeeName,
    required this.employeeId,
    required this.department,
    required this.jobTitle,
  });

  final String employeeName;
  final String employeeId;
  final String? department;
  final String? jobTitle;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0x142563EB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: PulseClockColors.actionBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeName,
                  style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  'Employee ID: $employeeId',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_profileContextLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _profileContextLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? get _profileContextLabel {
    final List<String> values = <String>[
      if (jobTitle?.trim().isNotEmpty ?? false) jobTitle!.trim(),
      if (department?.trim().isNotEmpty ?? false) department!.trim(),
    ];
    return values.isEmpty ? null : values.join('  |  ');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: PulseClockTextStyles.cardSubtitle.copyWith(
        color: PulseClockColors.onBackgroundPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.items});

  final List<_ProfileActionItem> items;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int index = 0; index < items.length; index++) ...<Widget>[
            _ProfileActionRow(item: items[index]),
            if (index != items.length - 1)
              const Divider(height: 1, color: PulseClockColors.cardBorder),
          ],
        ],
      ),
    );
  }
}

class _ProfileActionItem {
  const _ProfileActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({required this.item});

  final _ProfileActionItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(item.icon, color: PulseClockColors.textSecondary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  color: PulseClockColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: PulseClockColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
