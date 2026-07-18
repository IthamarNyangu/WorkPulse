import 'package:flutter/material.dart';
import 'package:pulseclock/features/geofence/data/geofence_exception_service.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

enum _GeofenceReviewFilter {
  all,
  outsideAllOffices,
  lowAccuracy,
  locationUnavailable,
  noOfficesConfigured,
}

extension _GeofenceReviewFilterLabels on _GeofenceReviewFilter {
  String get label {
    switch (this) {
      case _GeofenceReviewFilter.all:
        return 'All';
      case _GeofenceReviewFilter.outsideAllOffices:
        return 'Outside Offices';
      case _GeofenceReviewFilter.lowAccuracy:
        return 'Low Accuracy';
      case _GeofenceReviewFilter.locationUnavailable:
        return 'Unavailable';
      case _GeofenceReviewFilter.noOfficesConfigured:
        return 'No Offices';
    }
  }

  bool matches(GeofenceExceptionItem item) {
    switch (this) {
      case _GeofenceReviewFilter.all:
        return true;
      case _GeofenceReviewFilter.outsideAllOffices:
        return item.status == ClockLocationStatus.outsideAllOffices;
      case _GeofenceReviewFilter.lowAccuracy:
        return item.status == ClockLocationStatus.lowAccuracy;
      case _GeofenceReviewFilter.locationUnavailable:
        return item.status == ClockLocationStatus.locationUnavailable;
      case _GeofenceReviewFilter.noOfficesConfigured:
        return item.status == ClockLocationStatus.noOfficesConfigured;
    }
  }
}

class GeofenceExceptionReviewScreen extends StatefulWidget {
  const GeofenceExceptionReviewScreen({super.key});

  @override
  State<GeofenceExceptionReviewScreen> createState() =>
      _GeofenceExceptionReviewScreenState();
}

class _GeofenceExceptionReviewScreenState
    extends State<GeofenceExceptionReviewScreen> {
  final GeofenceExceptionService _service = GeofenceExceptionService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  _GeofenceReviewFilter _selectedFilter = _GeofenceReviewFilter.all;
  List<GeofenceExceptionItem> _exceptions = const <GeofenceExceptionItem>[];

  List<GeofenceExceptionItem> get _filteredExceptions {
    final String query = _searchQuery.trim().toLowerCase();
    return _exceptions
        .where((GeofenceExceptionItem item) {
          if (!_selectedFilter.matches(item)) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final String searchableText = <String>[
            item.employeeName,
            item.employeeId,
            item.action.label,
            item.status.label,
            item.dateLabelText,
            item.actionTimeLabel,
            item.coordinates ?? '',
            item.officeDisplayName ?? '',
            item.attendanceStatus ?? '',
          ].join(' ').toLowerCase();
          return searchableText.contains(query);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadExceptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExceptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<GeofenceExceptionItem> exceptions = await _service
          .fetchExceptions();
      if (!mounted) {
        return;
      }
      setState(() {
        _exceptions = exceptions;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exceptions = const <GeofenceExceptionItem>[];
        _isLoading = false;
        _errorMessage = 'Unable to load geofence exceptions right now.';
      });
    }
  }

  void _openDetails(GeofenceExceptionItem item) {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => GeofenceExceptionDetailsScreen(item: item),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: const Text('Geofence Review'),
      ),
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PulseClockColors.appBackground,
              PulseClockColors.appBackgroundDeep,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PulseClockDimensions.horizontalPadding,
              20,
              PulseClockDimensions.horizontalPadding,
              24,
            ),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            PulseClockColors.onBackgroundPrimary,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SurfaceCard(
          child: Text(
            _errorMessage!,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final List<GeofenceExceptionItem> filteredExceptions = _filteredExceptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review attendance actions with unusual GPS verification results.',
          style: PulseClockTextStyles.headerSubtitle.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 14),
        _GeofenceSearchField(
          controller: _searchController,
          onChanged: (String value) {
            setState(() {
              _searchQuery = value;
            });
          },
          onClear: _searchQuery.isEmpty
              ? null
              : () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final _GeofenceReviewFilter filter
                  in _GeofenceReviewFilter.values) ...<Widget>[
                _GeofenceFilterPill(
                  label: filter.label,
                  isSelected: filter == _selectedFilter,
                  onTap: () {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${filteredExceptions.length} exceptions from the last 90 days',
          style: PulseClockTextStyles.cardSubtitle.copyWith(
            color: PulseClockColors.onBackgroundSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadExceptions,
            child: filteredExceptions.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const <Widget>[
                      SizedBox(height: 150),
                      _EmptyGeofenceExceptionsCard(),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (BuildContext context, int index) {
                      final GeofenceExceptionItem item =
                          filteredExceptions[index];
                      return _GeofenceExceptionCard(
                        item: item,
                        onTap: () => _openDetails(item),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 8),
                    itemCount: filteredExceptions.length,
                  ),
          ),
        ),
      ],
    );
  }
}

class GeofenceExceptionDetailsScreen extends StatelessWidget {
  const GeofenceExceptionDetailsScreen({super.key, required this.item});

  final GeofenceExceptionItem item;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _locationStatusColor(item.status);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: const Text('Location Exception Details'),
      ),
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PulseClockColors.appBackground,
              PulseClockColors.appBackgroundDeep,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              PulseClockDimensions.horizontalPadding,
              20,
              PulseClockDimensions.horizontalPadding,
              24,
            ),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.employeeName,
                          style: PulseClockTextStyles.cardTitle.copyWith(
                            fontSize: 22,
                          ),
                        ),
                      ),
                      _LocationStatusBadge(status: item.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Employee ID: ${item.employeeId}',
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: PulseClockColors.cardBorder),
                  const SizedBox(height: 14),
                  _DetailRow(
                    label: 'Date',
                    value: fullDateLabel(item.workDate),
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(label: 'Action', value: item.action.label),
                  const SizedBox(height: 10),
                  _DetailRow(label: 'Time', value: item.actionTimeLabel),
                  const SizedBox(height: 10),
                  _DetailRow(
                    label: 'Attendance Status',
                    value: _attendanceStatusLabel(item.attendanceStatus),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _exceptionSummary(item),
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: PulseClockColors.cardBorder),
                  const SizedBox(height: 14),
                  _DetailRow(
                    label: 'Coordinates',
                    value: item.coordinates ?? 'Not captured',
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    label: 'GPS Accuracy',
                    value: item.accuracyMeters == null
                        ? 'Not captured'
                        : '${item.accuracyMeters!.toStringAsFixed(1)} m',
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    label: item.status == ClockLocationStatus.insideOffice
                        ? 'Verified Office'
                        : 'Nearest Office',
                    value: item.officeDisplayName ?? 'Not available',
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    label: 'Distance',
                    value: item.distanceMeters == null
                        ? 'Not available'
                        : _metersLabel(item.distanceMeters!),
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    label: 'Allowed Radius',
                    value: item.geofenceRadiusMeters == null
                        ? 'Not available'
                        : _metersLabel(item.geofenceRadiusMeters!),
                  ),
                  if (item.comment?.trim().isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 14),
                    const Divider(color: PulseClockColors.cardBorder),
                    const SizedBox(height: 14),
                    Text(
                      'Employee Comment',
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        color: PulseClockColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.comment!,
                      style: PulseClockTextStyles.cardSubtitle,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GeofenceExceptionCard extends StatelessWidget {
  const _GeofenceExceptionCard({required this.item, required this.onTap});

  final GeofenceExceptionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _locationStatusColor(item.status);

    return Material(
      color: PulseClockColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PulseClockColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 58,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.employeeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PulseClockTextStyles.cardSubtitle.copyWith(
                              color: PulseClockColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _LocationStatusBadge(status: item.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.action.label} | ${item.dateLabelText} at ${item.actionTimeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.officeDisplayName == null
                          ? item.status.label
                          : '${item.status.label} | ${item.officeDisplayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        color: PulseClockColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: PulseClockColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeofenceSearchField extends StatelessWidget {
  const _GeofenceSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: PulseClockTextStyles.cardSubtitle.copyWith(
        color: PulseClockColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Search employee, office, status, date',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: PulseClockColors.textSecondary,
        ),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(
                  Icons.close_rounded,
                  color: PulseClockColors.textSecondary,
                ),
              ),
        filled: true,
        fillColor: PulseClockColors.surface,
        hintStyle: PulseClockTextStyles.cardSubtitle.copyWith(fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PulseClockColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PulseClockColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: PulseClockColors.actionBlue,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _GeofenceFilterPill extends StatelessWidget {
  const _GeofenceFilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? PulseClockColors.actionBlue
              : PulseClockColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PulseClockColors.cardBorder),
        ),
        child: Text(
          label,
          style: PulseClockTextStyles.cardSubtitle.copyWith(
            color: isSelected
                ? PulseClockColors.surface
                : PulseClockColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LocationStatusBadge extends StatelessWidget {
  const _LocationStatusBadge({required this.status});

  final ClockLocationStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = _locationStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _shortStatusLabel(status),
        style: PulseClockTextStyles.cardSubtitle.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 122,
          child: Text(label, style: PulseClockTextStyles.cardSubtitle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyGeofenceExceptionsCard extends StatelessWidget {
  const _EmptyGeofenceExceptionsCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: PulseClockColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No geofence exceptions found.',
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                color: PulseClockColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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

String _shortStatusLabel(ClockLocationStatus status) {
  switch (status) {
    case ClockLocationStatus.insideOffice:
      return 'Verified';
    case ClockLocationStatus.outsideAllOffices:
      return 'Outside';
    case ClockLocationStatus.locationUnavailable:
      return 'Unavailable';
    case ClockLocationStatus.lowAccuracy:
      return 'Low Accuracy';
    case ClockLocationStatus.noOfficesConfigured:
      return 'No Offices';
  }
}

String _exceptionSummary(GeofenceExceptionItem item) {
  switch (item.status) {
    case ClockLocationStatus.outsideAllOffices:
      final String office = item.officeDisplayName ?? 'the nearest office';
      final String distance = item.distanceMeters == null
          ? 'an unknown distance'
          : _metersLabel(item.distanceMeters!);
      return '${item.action.label} happened outside all approved offices. Nearest office: $office, $distance away.';
    case ClockLocationStatus.lowAccuracy:
      return '${item.action.label} used low GPS accuracy and should be reviewed before relying on the location.';
    case ClockLocationStatus.locationUnavailable:
      return '${item.action.label} did not capture a usable GPS location.';
    case ClockLocationStatus.noOfficesConfigured:
      return 'No active office was configured when this ${item.action.label.toLowerCase()} was recorded.';
    case ClockLocationStatus.insideOffice:
      return 'Location was verified.';
  }
}

String _attendanceStatusLabel(String? status) {
  switch (status) {
    case 'on_duty':
      return 'On Duty';
    case 'completed':
      return 'Completed';
    case 'missed_punch':
      return 'Missed Punch';
    case 'absent':
      return 'Absent';
    case 'on_leave':
      return 'On Leave';
    case 'leave_pending':
      return 'Leave Pending';
    case 'correction_pending':
      return 'Correction Pending';
    default:
      return 'Unknown';
  }
}

String _metersLabel(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
  return '${meters.toStringAsFixed(0)} m';
}
