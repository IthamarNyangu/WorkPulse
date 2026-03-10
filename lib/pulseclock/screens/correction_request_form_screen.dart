import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class CorrectionRequestFormScreen extends StatefulWidget {
  const CorrectionRequestFormScreen({
    super.key,
    required this.attendanceRecordId,
    required this.affectedDate,
    required this.issueSummary,
    this.initialCorrectionType,
    this.existingRequestId,
    this.initialCorrectedClockInTime,
    this.initialCorrectedClockOutTime,
    this.initialReason,
  });

  final String attendanceRecordId;
  final DateTime affectedDate;
  final String issueSummary;
  final CorrectionType? initialCorrectionType;
  final String? existingRequestId;
  final String? initialCorrectedClockInTime;
  final String? initialCorrectedClockOutTime;
  final String? initialReason;

  @override
  State<CorrectionRequestFormScreen> createState() =>
      _CorrectionRequestFormScreenState();
}

class _CorrectionRequestFormScreenState extends State<CorrectionRequestFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _clockInController = TextEditingController();
  final TextEditingController _clockOutController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final WorkPulseMockStore _store = WorkPulseMockStore.instance;

  late final AttendanceRecord? _sourceRecord;
  late CorrectionType _selectedType;
  bool _isSubmitting = false;

  bool get _needsClockIn {
    return _selectedType == CorrectionType.clockIn ||
        _selectedType == CorrectionType.both;
  }

  bool get _needsClockOut {
    return _selectedType == CorrectionType.clockOut ||
        _selectedType == CorrectionType.both;
  }

  bool get _hasClockInRecord {
    final String? value = _sourceRecord?.clockInTime;
    return value != null && value.trim().isNotEmpty && value != '--';
  }

  bool get _isMissingClockOut {
    return _sourceRecord?.clockOutTime == '--' && _hasClockInRecord;
  }

  bool get _isMissingClockIn {
    final String? clockIn = _sourceRecord?.clockInTime;
    final String? clockOut = _sourceRecord?.clockOutTime;
    final bool hasClockOut =
        clockOut != null && clockOut.trim().isNotEmpty && clockOut != '--';
    return (clockIn == null || clockIn.trim().isEmpty || clockIn == '--') &&
        hasClockOut;
  }

  List<CorrectionType> get _availableCorrectionTypes {
    if (_isMissingClockOut) {
      return const <CorrectionType>[
        CorrectionType.clockOut,
        CorrectionType.both,
      ];
    }
    if (_isMissingClockIn) {
      return const <CorrectionType>[
        CorrectionType.clockIn,
        CorrectionType.both,
      ];
    }
    return CorrectionType.values;
  }

  @override
  void initState() {
    super.initState();
    _sourceRecord = _store.attendanceRecordById(widget.attendanceRecordId);
    if (widget.initialCorrectedClockInTime != null) {
      _clockInController.text = widget.initialCorrectedClockInTime!.trim();
    }
    if (widget.initialCorrectedClockOutTime != null) {
      _clockOutController.text = widget.initialCorrectedClockOutTime!.trim();
    }
    if (widget.initialReason != null) {
      _reasonController.text = widget.initialReason!.trim();
    }

    final bool shouldPreselectClockOut = _isMissingClockOut;
    final CorrectionType initialType =
        widget.initialCorrectionType ??
        (shouldPreselectClockOut ? CorrectionType.clockOut : CorrectionType.both);
    _selectedType = _availableCorrectionTypes.contains(initialType)
        ? initialType
        : (_isMissingClockIn
              ? CorrectionType.both
              : _availableCorrectionTypes.first);
    _syncPrefilledClockIn();
  }

  @override
  void dispose() {
    _clockInController.dispose();
    _clockOutController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickCorrectedClockIn() async {
    final TimeOfDay initialTime =
        _parseTimeOrDefault(_clockInController.text) ?? TimeOfDay.now();
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _clockInController.text = _formatTimeOfDay(selected);
    });
  }

  Future<void> _pickCorrectedClockOut() async {
    final TimeOfDay initialTime =
        _parseTimeOrDefault(_clockOutController.text) ?? TimeOfDay.now();
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _clockOutController.text = _formatTimeOfDay(selected);
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (_sourceRecord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance record no longer exists.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      _store.submitCorrectionRequest(
        attendanceRecordId: _sourceRecord!.id,
        issueSummary: widget.issueSummary,
        correctionType: _selectedType,
        reason: _reasonController.text.trim(),
        correctedClockInTime: _needsClockIn ? _clockInController.text.trim() : null,
        correctedClockOutTime: _needsClockOut ? _clockOutController.text.trim() : null,
        existingRequestId: widget.existingRequestId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to submit correction request.')),
      );
    }
  }

  void _syncPrefilledClockIn() {
    if (_isMissingClockOut && _needsClockIn && _hasClockInRecord) {
      if (_clockInController.text.trim().isEmpty) {
        _clockInController.text = _sourceRecord!.clockInTime;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Correction Request'),
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
              PulseClockDimensions.topPadding,
              PulseClockDimensions.horizontalPadding,
              28,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DetailInfoRow(
                          label: 'Affected Date',
                          value: dateLabel(widget.affectedDate),
                        ),
                        if ((_selectedType == CorrectionType.clockOut ||
                                _selectedType == CorrectionType.both) &&
                            _hasClockInRecord) ...<Widget>[
                          const SizedBox(height: 10),
                          DetailInfoRow(
                            label: 'Clocked In Time',
                            value: _sourceRecord!.clockInTime,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Issue Summary',
                          style: PulseClockTextStyles.cardSubtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.issueSummary,
                          style: PulseClockTextStyles.cardSubtitle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Correction Type',
                          style: PulseClockTextStyles.cardTitle.copyWith(
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableCorrectionTypes.map((
                            CorrectionType type,
                          ) {
                            return ChoiceChip(
                              label: Text(type.label),
                              selected: _selectedType == type,
                              onSelected: _isSubmitting
                                  ? null
                                  : (_) {
                                      setState(() {
                                        _selectedType = type;
                                        _syncPrefilledClockIn();
                                      });
                                    },
                              labelStyle: PulseClockTextStyles.cardSubtitle.copyWith(
                                color: _selectedType == type
                                    ? PulseClockColors.surface
                                    : PulseClockColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              selectedColor: PulseClockColors.actionBlue,
                              backgroundColor: PulseClockColors.surfaceMuted,
                              side: BorderSide(
                                color: _selectedType == type
                                    ? PulseClockColors.actionBlue
                                    : PulseClockColors.cardBorder,
                              ),
                              showCheckmark: false,
                            );
                          }).toList(growable: false),
                        ),
                        if (_needsClockIn) ...<Widget>[
                          const SizedBox(height: 14),
                          _TimeField(
                            label: 'Corrected Clock In Time',
                            controller: _clockInController,
                            enabled: !_isSubmitting,
                            onTap: _pickCorrectedClockIn,
                            validator: (String? value) {
                              if (!_needsClockIn) {
                                return null;
                              }
                              if (value == null || value.trim().isEmpty) {
                                return 'Select corrected Clock In time';
                              }
                              return null;
                            },
                          ),
                        ],
                        if (_needsClockOut) ...<Widget>[
                          const SizedBox(height: 12),
                          _TimeField(
                            label: 'Corrected Clock Out Time',
                            controller: _clockOutController,
                            enabled: !_isSubmitting,
                            onTap: _pickCorrectedClockOut,
                            validator: (String? value) {
                              if (!_needsClockOut) {
                                return null;
                              }
                              if (value == null || value.trim().isEmpty) {
                                return 'Select corrected Clock Out time';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reasonController,
                          enabled: !_isSubmitting,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Reason / Note',
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
                          validator: (String? value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Reason is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PulseClockColors.actionBlue,
                              foregroundColor: PulseClockColors.surface,
                              disabledBackgroundColor: PulseClockColors.actionBlue
                                  .withOpacity(0.65),
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
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        PulseClockColors.surface,
                                      ),
                                    ),
                                  )
                                : const Text('Submit'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onTap,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onTap;
  final String? Function(String? value) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      enabled: enabled,
      onTap: onTap,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.schedule_outlined),
        filled: true,
        fillColor: PulseClockColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PulseClockColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PulseClockColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: PulseClockColors.actionBlue,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

TimeOfDay? _parseTimeOrDefault(String value) {
  final RegExp expression = RegExp(r'^(\d{1,2}):(\d{2})\s?(AM|PM)$');
  final Match? match = expression.firstMatch(value.trim().toUpperCase());
  if (match == null) {
    return null;
  }

  int hour = int.parse(match.group(1)!);
  final int minute = int.parse(match.group(2)!);
  final String period = match.group(3)!;

  if (period == 'PM' && hour != 12) {
    hour += 12;
  }
  if (period == 'AM' && hour == 12) {
    hour = 0;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTimeOfDay(TimeOfDay value) {
  final int hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
  final String period = value.period == DayPeriod.am ? 'AM' : 'PM';
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}
