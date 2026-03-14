import 'package:flutter/material.dart';
import 'package:pulseclock/pulseclock/data/pulse_clock_mock_data.dart';
import 'package:pulseclock/pulseclock/models/pulse_clock_models.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/utils/pulse_clock_formatters.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class LeaveFormScreen extends StatefulWidget {
  const LeaveFormScreen({super.key, this.initialRequestId});

  final String? initialRequestId;

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final WorkPulseMockStore _store = WorkPulseMockStore.instance;

  late LeaveType _selectedType;
  late DateTime _startDate;
  late DateTime _endDate;
  LeaveRequest? _editingRequest;
  bool _isSubmitting = false;

  bool get _isEditing => _editingRequest != null;

  int get _durationDays {
    final DateTime start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final DateTime end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    return end.difference(start).inDays + 1;
  }

  String get _durationSummary {
    if (_durationDays <= 1) {
      return 'Single-day leave';
    }
    return 'Duration: $_durationDays days';
  }

  @override
  void initState() {
    super.initState();
    final DateTime today = DateTime.now();
    _selectedType = LeaveType.annualLeave;
    _startDate = DateTime(today.year, today.month, today.day);
    _endDate = DateTime(today.year, today.month, today.day);

    if (widget.initialRequestId != null) {
      final LeaveRequest? request = _store.leaveRequestById(widget.initialRequestId!);
      if (request != null) {
        _editingRequest = request;
        _selectedType = request.type;
        _startDate = request.startDate;
        _endDate = request.endDate;
        _reasonController.text = request.reason;
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    if (_isSubmitting) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 1, 1, 1);
    final DateTime lastDate = DateTime(now.year + 2, 12, 31);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    if (_isSubmitting) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 1, 1, 1);
    final DateTime lastDate = DateTime(now.year + 2, 12, 31);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate.isBefore(_startDate)) {
        _startDate = _endDate;
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isEditing) {
        _store.updatePendingLeaveRequest(
          requestId: _editingRequest!.id,
          type: _selectedType,
          startDate: _startDate,
          endDate: _endDate,
          reason: _reasonController.text.trim(),
        );
      } else {
        _store.submitLeaveRequest(
          type: _selectedType,
          startDate: _startDate,
          endDate: _endDate,
          reason: _reasonController.text.trim(),
        );
      }

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
        const SnackBar(content: Text('Unable to submit leave request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseClockColors.appBackground,
      appBar: AppBar(
        title: const Text('Submit Leave Request'),
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
                        Text(
                          'Leave Type',
                          style: PulseClockTextStyles.cardTitle.copyWith(
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: LeaveType.values.map((LeaveType type) {
                            return ChoiceChip(
                              label: Text(type.label),
                              selected: _selectedType == type,
                              onSelected: _isSubmitting
                                  ? null
                                  : (_) {
                                      setState(() {
                                        _selectedType = type;
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
                        const SizedBox(height: 14),
                        _DateField(
                          label: 'Start Date',
                          value: dateLabel(_startDate),
                          onTap: _pickStartDate,
                        ),
                        const SizedBox(height: 10),
                        _DateField(
                          label: 'End Date',
                          value: dateLabel(_endDate),
                          onTap: _pickEndDate,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _durationSummary,
                          style: PulseClockTextStyles.cardSubtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reasonController,
                          enabled: !_isSubmitting,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Reason / Comment',
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
                                : const Text('Submit Leave Request'),
                          ),
                        ),
                      ],
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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: PulseClockColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PulseClockColors.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: PulseClockTextStyles.cardSubtitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(value, style: PulseClockTextStyles.cardSubtitle),
                ],
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 18),
          ],
        ),
      ),
    );
  }
}
