import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/data/attendance_service.dart';
import 'package:pulseclock/features/attendance/location/workpulse_location_service.dart';
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
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double keyboardInset = MediaQuery.viewInsetsOf(
                context,
              ).bottom;
              final bool isKeyboardOpen = keyboardInset > 0;

              return SingleChildScrollView(
                controller: _scrollController,
                physics: isKeyboardOpen
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                padding: EdgeInsets.only(bottom: isKeyboardOpen ? 16 : 0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PulseClockDimensions.horizontalPadding,
                      22,
                      PulseClockDimensions.horizontalPadding,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConfirmationDateTimeHeader(now: now),
                        const SizedBox(height: 22),
                        ClockMapPlaceholderCard(
                          result: _locationResult,
                          isLoading: _isLoadingLocation,
                          onRetry: _isSubmitting ? null : _refreshLocation,
                        ),
                        const SizedBox(height: 10),
                        SurfaceCard(
                          key: _commentCardKey,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Comment (Optional)',
                                style: PulseClockTextStyles.cardTitle.copyWith(
                                  fontSize: 18,
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
                                    color: PulseClockColors.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: PulseClockColors.surfaceMuted,
                                  contentPadding: const EdgeInsets.all(12),
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
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _confirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.mode.color,
                              foregroundColor: PulseClockColors.surface,
                              disabledBackgroundColor: widget.mode.color
                                  .withOpacity(0.65),
                              disabledForegroundColor: PulseClockColors.surface,
                              textStyle: PulseClockTextStyles.primaryAction
                                  .copyWith(fontSize: 18),
                              padding: const EdgeInsets.symmetric(
                                vertical: 13,
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
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  PulseClockColors.onBackgroundPrimary,
                              backgroundColor: const Color(0x22000000),
                              side: BorderSide.none,
                              disabledForegroundColor: PulseClockColors
                                  .onBackgroundSecondary
                                  .withOpacity(0.75),
                              disabledBackgroundColor: const Color(0x16000000),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: PulseClockTextStyles.contextAction
                                  .copyWith(
                                    color: PulseClockColors.onBackgroundPrimary,
                                    fontSize: 15,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

String _friendlyPostgrestError(PostgrestException error) {
  final String details = error.message.trim();
  if (details.isEmpty) {
    return 'Attendance could not be saved to Supabase right now.';
  }
  return 'Attendance could not be saved: $details';
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
    return Center(
      child: Column(
        children: [
          Text(
            timeLabel(now),
            style: PulseClockTextStyles.timeOnBackground.copyWith(
              fontSize: 31,
              color: PulseClockColors.onBackgroundPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fullDateLabel(now),
            style: PulseClockTextStyles.weekdayOnBackground.copyWith(
              color: PulseClockColors.onBackgroundPrimary,
              fontSize: 15,
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

    return SurfaceCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Location Verification',
                style: PulseClockTextStyles.cardSubtitle.copyWith(
                  color: PulseClockColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (!isLoading && onRetry != null)
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    foregroundColor: PulseClockColors.actionBlue,
                    side: const BorderSide(
                      color: PulseClockColors.actionBlue,
                      width: 1,
                    ),
                    textStyle: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _MapPreview(
            hasLocation: hasLocation,
            isLoading: isLoading,
            statusColor: statusColor,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasLocation
                  ? _locationStatusMessage(snapshot)
                  : (result?.message ??
                        'GPS status will be attached when available.'),
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.hasLocation,
    required this.isLoading,
    required this.statusColor,
  });

  final bool hasLocation;
  final bool isLoading;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 154,
        decoration: const BoxDecoration(color: Color(0xFF596C52)),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapPreviewPainter())),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isLoading
                    ? const SizedBox(
                        key: ValueKey<String>('loading'),
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.6),
                      )
                    : Column(
                        key: ValueKey<bool>(hasLocation),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasLocation
                                ? Icons.location_pin
                                : Icons.location_searching_rounded,
                            size: 46,
                            color: hasLocation
                                ? statusColor
                                : PulseClockColors.textSecondary,
                          ),
                        ],
                      ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: PulseClockColors.surface.withOpacity(0.85),
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
          ],
        ),
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint basePaint = Paint()..color = const Color(0xFF5F714F);
    final Paint fieldPaint = Paint()..color = const Color(0xFF6F805A);
    final Paint darkFieldPaint = Paint()..color = const Color(0xFF455C3D);
    final Paint earthPaint = Paint()..color = const Color(0xFF9B8A63);
    final Paint roofPaint = Paint()..color = const Color(0xFFB9B1A3);
    final Paint roadPaint = Paint()
      ..color = const Color(0xFFDDD8C9).withOpacity(0.94)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    final Paint minorRoadPaint = Paint()
      ..color = const Color(0xFFC8C3B6).withOpacity(0.82)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    final Paint boundaryPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;

    canvas.drawRect(Offset.zero & size, basePaint);

    void drawParcel(List<Offset> points, Paint paint) {
      final Path path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final Offset point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withOpacity(0.05),
      );
    }

    drawParcel(<Offset>[
      const Offset(-10, 0),
      Offset(size.width * 0.35, 0),
      Offset(size.width * 0.26, size.height * 0.42),
      Offset(0, size.height * 0.36),
    ], fieldPaint);
    drawParcel(<Offset>[
      Offset(size.width * 0.35, 0),
      Offset(size.width, 0),
      Offset(size.width * 0.9, size.height * 0.35),
      Offset(size.width * 0.26, size.height * 0.42),
    ], darkFieldPaint);
    drawParcel(<Offset>[
      Offset(0, size.height * 0.36),
      Offset(size.width * 0.26, size.height * 0.42),
      Offset(size.width * 0.18, size.height),
      const Offset(-12, 140),
    ], earthPaint);
    drawParcel(<Offset>[
      Offset(size.width * 0.26, size.height * 0.42),
      Offset(size.width * 0.9, size.height * 0.35),
      Offset(size.width, size.height),
      Offset(size.width * 0.18, size.height),
    ], fieldPaint);

    canvas.drawLine(
      Offset(-18, size.height * 0.2),
      Offset(size.width + 18, size.height * 0.1),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, -12),
      Offset(size.width * 0.76, size.height + 16),
      roadPaint,
    );
    canvas.drawLine(
      Offset(-14, size.height * 0.72),
      Offset(size.width + 14, size.height * 0.56),
      minorRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height + 12),
      Offset(size.width * 0.44, -14),
      minorRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.64, -10),
      Offset(size.width * 0.92, size.height + 10),
      minorRoadPaint,
    );

    for (double y = 18; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 13), boundaryPaint);
    }
    for (double x = 24; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x - 24, size.height), boundaryPaint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.13, size.height * 0.48, 36, 18),
        const Radius.circular(3),
      ),
      roofPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.73, size.height * 0.22, 42, 22),
        const Radius.circular(4),
      ),
      roofPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.58, size.height * 0.72, 54, 20),
        const Radius.circular(4),
      ),
      Paint()..color = roofPaint.color.withOpacity(0.9),
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1C2740).withOpacity(0.1),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

String _metersLabel(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
  return '${meters.toStringAsFixed(0)} m';
}
