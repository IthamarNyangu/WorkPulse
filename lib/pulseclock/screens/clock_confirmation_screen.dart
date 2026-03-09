import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class ClockConfirmationScreen extends StatefulWidget {
  const ClockConfirmationScreen({super.key, required this.mode});

  final ClockActionMode mode;

  @override
  State<ClockConfirmationScreen> createState() =>
      _ClockConfirmationScreenState();
}

class _ClockConfirmationScreenState extends State<ClockConfirmationScreen> {
  static const ClockLocationSnapshot _mockLocation = ClockLocationSnapshot(
    coordinates: '-15.3875, 28.3228',
    accuracyMeters: 8.0,
    isInsideGeofence: true,
  );

  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _confirm() {
    final String comment = _commentController.text.trim();
    Navigator.of(context).pop(
      ClockConfirmationResult(
        mode: widget.mode,
        timestamp: DateTime.now(),
        comment: comment.isEmpty ? null : comment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: Text(widget.mode.title),
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111827), Color(0x995A1622)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              PulseClockDimensions.horizontalPadding,
              PulseClockDimensions.topPadding,
              PulseClockDimensions.horizontalPadding,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClockLocationCard(snapshot: _mockLocation),
                const SizedBox(height: 16),
                const ClockMapPlaceholderCard(),
                const SizedBox(height: 16),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comment (Optional)',
                        style: PulseClockTextStyles.cardTitle.copyWith(
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add a note for this attendance action',
                          hintStyle: const TextStyle(
                            color: PulseClockColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: PulseClockColors.surfaceMuted,
                          contentPadding: const EdgeInsets.all(14),
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
                            borderSide: BorderSide(
                              color: widget.mode.color,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: Icon(widget.mode.icon, size: 24),
                    label: Text(widget.mode.confirmLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.mode.color,
                      foregroundColor: PulseClockColors.surface,
                      textStyle: PulseClockTextStyles.primaryAction.copyWith(
                        fontSize: 20,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          PulseClockDimensions.cardRadius,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ClockLocationCard extends StatelessWidget {
  const ClockLocationCard({super.key, required this.snapshot});

  final ClockLocationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final bool isInsideGeofence = snapshot.isInsideGeofence;
    final String geofenceLabel = isInsideGeofence
        ? 'Inside Geofence'
        : 'Outside Geofence';
    final Color geofenceColor = isInsideGeofence
        ? PulseClockColors.statusOnDutyAccent
        : PulseClockColors.statusMissedAccent;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.my_location_outlined,
                color: PulseClockColors.textPrimary,
              ),
              const SizedBox(width: 10),
              Text(
                'Location Snapshot',
                style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DetailInfoRow(label: 'Coordinates', value: snapshot.coordinates),
          const SizedBox(height: 8),
          DetailInfoRow(
            label: 'GPS Accuracy',
            value: '+/-${snapshot.accuracyMeters.toStringAsFixed(1)} m',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Geofence',
                  style: PulseClockTextStyles.cardSubtitle,
                ),
              ),
              Text(
                geofenceLabel,
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  color: geofenceColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ClockMapPlaceholderCard extends StatelessWidget {
  const ClockMapPlaceholderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PulseClockDimensions.cardRadius),
        child: Container(
          height: 170,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD7E0EC), Color(0xFFC4D0E2)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 46,
                  color: PulseClockColors.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Map Preview Placeholder',
                  style: PulseClockTextStyles.cardTitle.copyWith(
                    fontSize: 20,
                    color: PulseClockColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Live map integration coming soon',
                  style: PulseClockTextStyles.cardSubtitle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
