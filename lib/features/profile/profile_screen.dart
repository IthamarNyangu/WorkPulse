import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          const Text('Profile', style: PulseClockTextStyles.headerTitle),
          const SizedBox(height: 20),
          const SurfaceCard(
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: PulseClockColors.textSecondary,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Profile settings will appear here.',
                    style: PulseClockTextStyles.cardSubtitle,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
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
    );
  }
}
