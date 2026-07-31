import 'package:flutter/material.dart';

abstract final class PulseClockColors {
  static const Color appBackgroundSolid = Color(0xFF7A1E2C);
  static const Color appBackground = Color(0x997A1E2C);
  static const Color appBackgroundDeep = Color(0x995A1622);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF6F8FC);
  static const Color cardBorder = Color(0x1A0E1B3D);

  static const Color onBackgroundPrimary = Color(0xFFFFFFFF);
  static const Color onBackgroundSecondary = Color(0xFFF2D4D7);
  static const Color textPrimary = Color(0xFF0E1B3D);
  static const Color textSecondary = Color(0xFF55637D);

  static const Color statusOffDutyBg = Color(0xFFECF1F8);
  static const Color statusOffDutyAccent = Color(0xFF2F3E52);

  static const Color statusOnDutyBg = Color(0xFFECF1F8);
  static const Color statusOnDutyAccent = Color(0xFF0F8A43);

  static const Color statusMissedBg = Color(0xFFFFE8EE);
  static const Color statusMissedAccent = Color(0xFFC81E3A);

  static const Color statusPendingBg = Color(0xFFFFF1D9);
  static const Color statusPendingAccent = Color(0xFFB45309);

  static const Color statusLeaveBg = Color(0xFFF1E9FF);
  static const Color statusLeaveAccent = Color(0xFF6B21A8);

  static const Color actionBlue = Color(0xFF2563EB);
  static const Color actionBlueSoft = Color(0xFFE8F0FF);
  static const Color actionBlueBorder = Color(0xFF9DB9F5);
  static const Color reportAction = Color(0xFF15803D);
  static const Color reportActionSoft = Color(0xFFE8F6EC);
  static const Color reportActionBorder = Color(0xFF8DCF9F);
  static const Color actionRed = Color(0xFFEC1D36);

  static const Color navSelected = Color(0xFF2563EB);
  static const Color navUnselected = Color(0xFF9CA3AF);
}

abstract final class PulseClockDimensions {
  static const double horizontalPadding = 20;
  static const double topPadding = 20;
  static const double cardRadius = 18;
  static const double sectionGap = 20;
}

abstract final class PulseClockShadows {
  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 10)),
  ];
}

abstract final class PulseClockTextStyles {
  static const TextStyle headerTitle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: PulseClockColors.onBackgroundPrimary,
    height: 1.1,
    letterSpacing: -0.4,
  );

  static const TextStyle headerSubtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: PulseClockColors.onBackgroundSecondary,
  );

  static const TextStyle weekdayOnBackground = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: PulseClockColors.onBackgroundSecondary,
  );

  static const TextStyle dateOnBackground = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: PulseClockColors.onBackgroundPrimary,
    letterSpacing: -0.4,
  );

  static const TextStyle timeOnBackground = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: PulseClockColors.onBackgroundPrimary,
    letterSpacing: -1,
    height: 1.05,
  );

  static const TextStyle sectionTitleOnBackground = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: PulseClockColors.onBackgroundPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: PulseClockColors.textPrimary,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: PulseClockColors.textSecondary,
  );

  static const TextStyle primaryAction = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: PulseClockColors.surface,
    letterSpacing: -0.2,
  );

  static const TextStyle summaryLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: PulseClockColors.textSecondary,
  );

  static const TextStyle summaryValue = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: PulseClockColors.textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle contextAction = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: PulseClockColors.actionBlue,
  );

  static const TextStyle switcherLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: PulseClockColors.onBackgroundSecondary,
  );
}
