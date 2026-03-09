import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class ClockConfirmationScreen extends StatefulWidget {
  const ClockConfirmationScreen({super.key, required this.mode});

  final ClockActionMode mode;

  @override
  State<ClockConfirmationScreen> createState() =>
      _ClockConfirmationScreenState();
}

class _ClockConfirmationScreenState extends State<ClockConfirmationScreen> {
  static const Duration _loadingIndicatorDelay = Duration(milliseconds: 250);

  static const ClockLocationSnapshot _mockLocation = ClockLocationSnapshot(
    coordinates: '-15.3875, 28.3228',
    accuracyMeters: 8.0,
    isInsideGeofence: true,
  );

  late final TextEditingController _commentController;
  bool _isSubmitting = false;
  bool _showLoadingIndicator = false;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _showLoadingIndicator = false;
    });
    _loadingTimer = Timer(_loadingIndicatorDelay, () {
      if (!mounted || !_isSubmitting) {
        return;
      }
      setState(() {
        _showLoadingIndicator = true;
      });
    });

    try {
      await _submitConfirmation();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to confirm action right now. Please try again.'),
        ),
      );
      setState(() {
        _isSubmitting = false;
        _showLoadingIndicator = false;
      });
      return;
    } finally {
      _loadingTimer?.cancel();
      _loadingTimer = null;
    }

    if (!mounted) {
      return;
    }

    final String comment = _commentController.text.trim();
    Navigator.of(context).pop(
      ClockConfirmationResult(
        mode: widget.mode,
        timestamp: DateTime.now(),
        comment: comment.isEmpty ? null : comment,
      ),
    );
  }

  Future<void> _submitConfirmation() async {
    // Placeholder for future API/location work. Kept async to preserve UX flow.
    await Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();

    return Scaffold(
      backgroundColor: PulseClockColors.appBackgroundSolid,
      appBar: AppBar(
        title: Text(widget.mode.title),
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1F2B45), PulseClockColors.appBackgroundSolid],
            stops: [0.0, 0.5],
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
                ConfirmationDateTimeHeader(now: now),
                const SizedBox(height: 24),
                ClockMapPlaceholderCard(snapshot: _mockLocation),
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
                        enabled: !_isSubmitting,
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
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.mode.color,
                      foregroundColor: PulseClockColors.surface,
                      disabledBackgroundColor: widget.mode.color.withOpacity(
                        0.65,
                      ),
                      disabledForegroundColor: PulseClockColors.surface,
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
                    child: _ConfirmButtonContent(
                      mode: widget.mode,
                      showLoadingIndicator: _showLoadingIndicator,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PulseClockColors.onBackgroundPrimary,
                      backgroundColor: const Color(0x22000000),
                      side: BorderSide.none,
                      disabledForegroundColor: PulseClockColors
                          .onBackgroundSecondary
                          .withOpacity(0.75),
                      disabledBackgroundColor: const Color(0x16000000),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: PulseClockTextStyles.contextAction.copyWith(
                        color: PulseClockColors.onBackgroundPrimary,
                        fontSize: 17,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          PulseClockDimensions.cardRadius,
                        ),
                      ),
                    ),
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

class _ConfirmButtonContent extends StatelessWidget {
  const _ConfirmButtonContent({
    required this.mode,
    required this.showLoadingIndicator,
  });

  final ClockActionMode mode;
  final bool showLoadingIndicator;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showLoadingIndicator)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(
                PulseClockColors.surface,
              ),
            ),
          )
        else
          Icon(mode.icon, size: 24),
        const SizedBox(width: 10),
        Text(mode.confirmLabel),
      ],
    );
  }
}

class ConfirmationDateTimeHeader extends StatelessWidget {
  const ConfirmationDateTimeHeader({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final String weekdayShort = weekdayName(now).substring(0, 3);

    return Center(
      child: Column(
        children: [
          Text(
            _time24Label(now),
            style: PulseClockTextStyles.timeOnBackground.copyWith(
              fontSize: 34,
              color: PulseClockColors.onBackgroundPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$weekdayShort ${dateLabel(now)}',
            style: PulseClockTextStyles.weekdayOnBackground.copyWith(
              color: PulseClockColors.onBackgroundPrimary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class ClockMapPlaceholderCard extends StatelessWidget {
  const ClockMapPlaceholderCard({super.key, required this.snapshot});

  // Kept for hot-reload compatibility while snapshot details are hidden.
  final ClockLocationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    assert(snapshot.coordinates.isNotEmpty);

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

String _time24Label(DateTime now) {
  final String hour = now.hour.toString().padLeft(2, '0');
  final String minute = now.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
