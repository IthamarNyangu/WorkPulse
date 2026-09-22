import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:postgrest/postgrest.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/features/attendance/location/workpulse_location_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';

class ClockConfirmationScreen extends StatefulWidget {
  const ClockConfirmationScreen({super.key, required this.mode});

  final ClockActionMode mode;

  @override
  State<ClockConfirmationScreen> createState() =>
      _ClockConfirmationScreenState();
}

class _ClockConfirmationScreenState extends State<ClockConfirmationScreen>
    with WidgetsBindingObserver {
  static const Duration _loadingIndicatorDelay = Duration(milliseconds: 250);

  final WorkPulseLocationService _locationService = WorkPulseLocationService();
  late final TextEditingController _commentController;
  late final FocusNode _commentFocusNode;
  late final ScrollController _scrollController;
  final GlobalKey _commentCardKey = GlobalKey();
  WorkPulseLocationResult? _locationResult;
  Future<void>? _locationLoad;
  bool _isSubmitting = false;
  bool _showLoadingIndicator = false;
  bool _isLoadingLocation = true;
  Timer? _loadingTimer;

  bool get _hasRequiredLocation => _locationResult?.snapshot != null;

  bool get _canConfirm =>
      !_isSubmitting && !_isLoadingLocation && _hasRequiredLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _commentController = TextEditingController();
    _commentFocusNode = FocusNode();
    _commentFocusNode.addListener(_onCommentFocusChanged);
    _scrollController = ScrollController();
    _locationLoad = _loadLocation();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _commentFocusNode.removeListener(_onCommentFocusChanged);
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!_commentFocusNode.hasFocus) {
      return;
    }
    _scrollCommentIntoView(delay: const Duration(milliseconds: 120));
    _scrollCommentIntoView(delay: const Duration(milliseconds: 360));
  }

  void _onCommentFocusChanged() {
    if (!_commentFocusNode.hasFocus) {
      return;
    }

    _queueCommentScroll();
  }

  void _queueCommentScroll() {
    _scrollCommentIntoView(delay: const Duration(milliseconds: 80));
    _scrollCommentIntoView(delay: const Duration(milliseconds: 220));
    _scrollCommentIntoView(delay: const Duration(milliseconds: 560));
  }

  Future<void> _scrollCommentIntoView({required Duration delay}) async {
    await Future<void>.delayed(delay);
    if (!mounted || !_commentFocusNode.hasFocus) {
      return;
    }

    final BuildContext? commentContext = _commentCardKey.currentContext;
    if (commentContext == null || !commentContext.mounted) {
      return;
    }

    await Scrollable.ensureVisible(
      commentContext,
      alignment: 0.56,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    final WorkPulseLocationResult result = await _locationService
        .captureCurrentLocation();
    if (!mounted) {
      return;
    }

    setState(() {
      _locationResult = result;
      _isLoadingLocation = false;
    });
  }

  Future<void> _refreshLocation() async {
    _locationLoad = _loadLocation();
    await _locationLoad;
  }

  Future<void> _confirm() async {
    if (_isSubmitting) {
      return;
    }
    if (!_hasRequiredLocation) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Turn on location services to ${widget.mode.confirmLabel.toLowerCase()}.',
            ),
          ),
        );
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
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
      setState(() {
        _isSubmitting = false;
        _showLoadingIndicator = false;
      });
      return;
    } on PostgrestException catch (error) {
      developer.log(
        'Attendance confirmation failed with PostgrestException',
        name: 'workpulse.clock_confirmation',
        error: error,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyPostgrestError(error))));
      setState(() {
        _isSubmitting = false;
        _showLoadingIndicator = false;
      });
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to confirm action right now. Please try again.',
          ),
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
    final ClockConfirmationResult result = ClockConfirmationResult(
      mode: widget.mode,
      timestamp: DateTime.now(),
      comment: comment.isEmpty ? null : comment,
      locationSnapshot: _locationResult?.snapshot,
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final bool isClockIn = widget.mode == ClockActionMode.clockIn;
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
            isClockIn ? 'Clock In Successful' : 'Clock Out Successful',
            style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
          ),
          content: Text(
            isClockIn
                ? 'You have clocked in successfully.'
                : 'You have clocked out successfully.',
            style: PulseClockTextStyles.cardSubtitle.copyWith(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(result);
  }

  Future<void> _submitConfirmation() async {
    if (_isLoadingLocation) {
      await _locationLoad;
    }

    if (!SupabaseBootstrap.isInitialized) {
      await Future<void>.value();
      return;
    }

    final AttendanceService attendanceService = AttendanceService();
    final ClockLocationSnapshot? locationSnapshot = _locationResult?.snapshot;
    final String comment = _commentController.text.trim();
    final String? safeComment = comment.isEmpty ? null : comment;
    final DateTime now = DateTime.now();

    if (widget.mode == ClockActionMode.clockIn) {
      final SupabaseAttendanceRecord record = await attendanceService
          .insertClockIn(
            comment: safeComment,
            clockInAt: now,
            locationSnapshot: locationSnapshot,
          );
      developer.log(
        'Clock in saved to Supabase: ${record.id}',
        name: 'workpulse.clock_confirmation',
      );
      final SupabaseAttendanceRecord? verificationRecord =
          await attendanceService.fetchTodaysAttendance(date: now);
      if (verificationRecord == null) {
        throw StateError(
          'Clock in did not appear in Supabase after saving. Please check your active Supabase project and try again.',
        );
      }
      return;
    }

    final SupabaseAttendanceRecord record = await attendanceService
        .insertClockOut(
          comment: safeComment,
          clockOutAt: now,
          locationSnapshot: locationSnapshot,
        );
    developer.log(
      'Clock out saved to Supabase: ${record.id}',
      name: 'workpulse.clock_confirmation',
    );
    final SupabaseAttendanceRecord? verificationRecord = await attendanceService
        .fetchTodaysAttendance(date: now);
    if (verificationRecord == null) {
      throw StateError(
        'Clock out could not be verified from Supabase after saving.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: PulseClockColors.appBackgroundSolid,
      appBar: AppBar(
        title: Text(
          widget.mode.title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 23,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
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
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double keyboardInset = MediaQuery.viewInsetsOf(
                context,
              ).bottom;
              final bool isKeyboardOpen = keyboardInset > 0;

              return SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                padding: EdgeInsets.only(bottom: isKeyboardOpen ? 16 : 0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PulseClockDimensions.horizontalPadding,
                      18,
                      PulseClockDimensions.horizontalPadding,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConfirmationDateTimeHeader(now: now),
                        const SizedBox(height: 18),
                        ClockMapPlaceholderCard(
                          result: _locationResult,
                          isLoading: _isLoadingLocation,
                          onRetry: _isSubmitting ? null : _refreshLocation,
                        ),
                        if (!_isLoadingLocation && !_hasRequiredLocation) ...[
                          const SizedBox(height: 8),
                          _LocationRequiredNotice(mode: widget.mode),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          key: _commentCardKey,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Comment (optional)',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: PulseClockColors.onBackgroundPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _commentController,
                                focusNode: _commentFocusNode,
                                enabled: !_isSubmitting,
                                maxLines: 2,
                                onTap: _queueCommentScroll,
                                scrollPadding: const EdgeInsets.only(
                                  bottom: 28,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Add a note for this attendance action',
                                  hintStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    color: PulseClockColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: PulseClockColors.surfaceMuted,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: PulseClockColors.cardBorder,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: PulseClockColors.cardBorder,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: _confirmationActionColor(
                                        widget.mode,
                                      ),
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _canConfirm ? _confirm : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _confirmationActionColor(
                                widget.mode,
                              ),
                              foregroundColor: PulseClockColors.surface,
                              disabledBackgroundColor: _hasRequiredLocation
                                  ? _confirmationActionColor(
                                      widget.mode,
                                    ).withValues(alpha: 0.65)
                                  : PulseClockColors.textSecondary.withValues(
                                      alpha: 0.35,
                                    ),
                              disabledForegroundColor: PulseClockColors.surface,
                              textStyle: PulseClockTextStyles.primaryAction
                                  .copyWith(
                                    fontFamily: 'Inter',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _ConfirmButtonContent(
                              mode: widget.mode,
                              showLoadingIndicator: _showLoadingIndicator,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  PulseClockColors.onBackgroundPrimary,
                              backgroundColor: const Color(0x22000000),
                              disabledForegroundColor: PulseClockColors
                                  .onBackgroundSecondary
                                  .withValues(alpha: 0.75),
                              disabledBackgroundColor: const Color(0x16000000),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              textStyle: PulseClockTextStyles.contextAction
                                  .copyWith(
                                    color: PulseClockColors.onBackgroundPrimary,
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Color _confirmationActionColor(ClockActionMode mode) {
  return mode == ClockActionMode.clockIn
      ? PulseClockColors.statusOnDutyAccent
      : const Color(0xFFC81E3A);
}

String _friendlyPostgrestError(PostgrestException error) {
  final String details = error.message.trim();
  if (details.isEmpty) {
    return 'Attendance could not be saved to Supabase right now.';
  }
  return 'Attendance could not be saved: $details';
}

class _LocationRequiredNotice extends StatelessWidget {
  const _LocationRequiredNotice({required this.mode});

  final ClockActionMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: PulseClockColors.statusMissedBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 17,
            color: PulseClockColors.statusMissedAccent,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Location is required before you can ${mode.confirmLabel.toLowerCase()}. Turn on phone location, then tap Retry.',
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                fontFamily: 'Inter',
                color: PulseClockColors.statusMissedAccent,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
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
          Icon(mode.icon, size: 21),
        const SizedBox(width: 8),
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
    return Center(
      child: Column(
        children: [
          Text(
            timeLabel(now),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1.05,
              color: PulseClockColors.onBackgroundPrimary,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fullDateLabel(now),
            style: const TextStyle(
              fontFamily: 'Inter',
              color: PulseClockColors.onBackgroundPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class ClockMapPlaceholderCard extends StatelessWidget {
  const ClockMapPlaceholderCard({
    super.key,
    required this.result,
    required this.isLoading,
    required this.onRetry,
  });

  final WorkPulseLocationResult? result;
  final bool isLoading;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final ClockLocationSnapshot? snapshot = result?.snapshot;
    final bool hasLocation = snapshot != null;
    final Color statusColor = hasLocation
        ? _locationStatusColor(snapshot.status)
        : PulseClockColors.statusPendingAccent;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFE),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: PulseClockColors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Location Verification',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: PulseClockColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isLoading && onRetry != null)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    foregroundColor: PulseClockColors.actionBlue,
                    textStyle: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _MapPreview(
            snapshot: snapshot,
            isLoading: isLoading,
            statusColor: statusColor,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasLocation && snapshot.isInsideGeofence
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 17,
                  color: statusColor,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    hasLocation
                        ? _locationStatusMessage(snapshot)
                        : (result?.message ??
                              'GPS status will be attached when available.'),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.3,
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

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.snapshot,
    required this.isLoading,
    required this.statusColor,
  });

  final ClockLocationSnapshot? snapshot;
  final bool isLoading;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final double? latitude = snapshot?.latitude;
    final double? longitude = snapshot?.longitude;
    final LatLng? point = latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 154,
        color: PulseClockColors.surfaceMuted,
        child: Stack(
          children: [
            if (point != null)
              Positioned.fill(
                child: FlutterMap(
                  key: ValueKey<String>(
                    '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
                  ),
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 17,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.workpulsezm.workpulse',
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: point,
                          radius: snapshot!.accuracyMeters
                              .clamp(8.0, 100.0)
                              .toDouble(),
                          useRadiusInMeter: true,
                          color: PulseClockColors.actionBlue.withValues(
                            alpha: 0.12,
                          ),
                          borderColor: PulseClockColors.actionBlue.withValues(
                            alpha: 0.42,
                          ),
                          borderStrokeWidth: 1.2,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 46,
                          height: 46,
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.location_pin,
                            size: 46,
                            color: statusColor,
                            shadows: const [
                              Shadow(color: Colors.black38, blurRadius: 5),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              const Positioned.fill(child: _MapUnavailableBackground()),
            if (isLoading)
              Positioned.fill(
                child: ColoredBox(
                  color: PulseClockColors.surface.withValues(alpha: 0.62),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: PulseClockColors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Map Preview',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    color: PulseClockColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (point != null)
              Positioned(
                right: 8,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  color: PulseClockColors.surface.withValues(alpha: 0.82),
                  child: Text(
                    '(c) OpenStreetMap contributors',
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      color: PulseClockColors.textSecondary,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapUnavailableBackground extends StatelessWidget {
  const _MapUnavailableBackground();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: PulseClockColors.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.location_searching_rounded,
          size: 42,
          color: PulseClockColors.textSecondary,
        ),
      ),
    );
  }
}

Color _locationStatusColor(ClockLocationStatus status) {
  switch (status) {
    case ClockLocationStatus.insideOffice:
      return PulseClockColors.statusOnDutyAccent;
    case ClockLocationStatus.outsideAllOffices:
      return PulseClockColors.statusMissedAccent;
    case ClockLocationStatus.lowAccuracy:
    case ClockLocationStatus.noOfficesConfigured:
      return PulseClockColors.statusPendingAccent;
    case ClockLocationStatus.locationUnavailable:
      return PulseClockColors.textSecondary;
  }
}

String _locationStatusMessage(ClockLocationSnapshot snapshot) {
  switch (snapshot.status) {
    case ClockLocationStatus.insideOffice:
      return 'Within Geofence of ${snapshot.verifiedOfficeName ?? 'an approved WorkPulse office'}.';
    case ClockLocationStatus.outsideAllOffices:
      return 'Outside Geofence of all approved WorkPulse offices.';
    case ClockLocationStatus.lowAccuracy:
      return 'GPS accuracy is too low to verify this location. This clock action will be flagged for review.';
    case ClockLocationStatus.noOfficesConfigured:
      return 'No active WorkPulse office locations are configured yet.';
    case ClockLocationStatus.locationUnavailable:
      return 'GPS status will be attached when available.';
  }
}
