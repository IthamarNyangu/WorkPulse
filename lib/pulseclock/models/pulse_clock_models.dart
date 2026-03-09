import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/styles.dart';

enum AttendanceStatus { offDuty, onDuty }

enum RequestEntryType { missedPunch, correctionPending, leaveDetails }

enum ClockActionMode { clockIn, clockOut }

extension ClockActionModeLabels on ClockActionMode {
  String get title {
    switch (this) {
      case ClockActionMode.clockIn:
        return 'Confirm Clock In';
      case ClockActionMode.clockOut:
        return 'Confirm Clock Out';
    }
  }

  String get confirmLabel {
    switch (this) {
      case ClockActionMode.clockIn:
        return 'Confirm Clock In';
      case ClockActionMode.clockOut:
        return 'Confirm Clock Out';
    }
  }

  IconData get icon {
    switch (this) {
      case ClockActionMode.clockIn:
        return Icons.login_rounded;
      case ClockActionMode.clockOut:
        return Icons.logout_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ClockActionMode.clockIn:
        return PulseClockColors.actionBlue;
      case ClockActionMode.clockOut:
        return PulseClockColors.actionRed;
    }
  }
}

class ClockConfirmationResult {
  const ClockConfirmationResult({
    required this.mode,
    required this.timestamp,
    this.comment,
  });

  final ClockActionMode mode;
  final DateTime timestamp;
  final String? comment;
}

class ClockLocationSnapshot {
  const ClockLocationSnapshot({
    required this.coordinates,
    required this.accuracyMeters,
    required this.isInsideGeofence,
  });

  final String coordinates;
  final double accuracyMeters;
  final bool isInsideGeofence;
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
