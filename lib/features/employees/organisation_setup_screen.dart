import 'package:flutter/material.dart';
import 'package:pulseclock/features/employees/department_management_screen.dart';
import 'package:pulseclock/features/employees/job_title_management_screen.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class OrganisationSetupScreen extends StatelessWidget {
  const OrganisationSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        title: const Text('Organisation Setup'),
      ),
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [PulseClockColors.appBackground, PulseClockColors.appBackgroundDeep],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Manage organisation data used when creating and updating employees.',
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  color: PulseClockColors.onBackgroundSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _SetupCard(
                icon: Icons.account_tree_outlined,
                title: 'Departments',
                subtitle: 'Add, rename, or deactivate departments.',
                onTap: () => _open(context, const DepartmentManagementScreen()),
              ),
              const SizedBox(height: 10),
              _SetupCard(
                icon: Icons.badge_outlined,
                title: 'Job Titles',
                subtitle: 'Maintain the titles available to employees.',
                onTap: () => _open(context, const JobTitleManagementScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Widget page) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PulseClockColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PulseClockColors.actionBlueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: PulseClockColors.actionBlue),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 17)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: PulseClockTextStyles.cardSubtitle.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: PulseClockColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
