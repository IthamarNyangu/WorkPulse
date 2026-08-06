import 'package:flutter/material.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/leave/data/leave_service.dart';
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
  AnnualLeaveBalance _annualLeaveBalance = const AnnualLeaveBalance(
    totalDays: LeaveService.defaultAnnualLeaveEntitlementDays,
    usedDays: 0,
    pendingDays: 0,
  );
  bool _isLoadingRequest = false;
  bool _isLoadingBalance = false;
  bool _isLoadingDuration = false;
  bool _isSubmitting = false;
  int _durationDays = 1;
  int _durationLoadVersion = 0;
  String? _submitErrorMessage;

  bool get _isEditing => _editingRequest != null;
  bool get _usesBackend => SupabaseBootstrap.isInitialized;

  String get _durationLabel {
    if (_isLoadingDuration) {
      return 'Calculating...';
    }
    if (_durationDays == 0) {
      return 'No Working Days';
    }
    if (_durationDays == 1) {
      return '1 Working Day';
    }
    return '$_durationDays Working Days';
  }

  @override
  void initState() {
    super.initState();
    final DateTime today = DateTime.now();
    _selectedType = LeaveType.annualLeave;
    _startDate = DateTime(today.year, today.month, today.day);
    _endDate = DateTime(today.year, today.month, today.day);
    _loadAnnualLeaveBalance();
    _loadLeaveDuration();

    if (widget.initialRequestId != null && _usesBackend) {
      _loadEditingRequest();
      return;
    }

    if (widget.initialRequestId != null) {
      final LeaveRequest? request = _store.leaveRequestById(
        widget.initialRequestId!,
      );
      if (request != null) {
        _applyEditingRequest(request);
        _loadLeaveDuration();
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadEditingRequest() async {
    setState(() {
      _isLoadingRequest = true;
    });

    try {
      final LeaveRequest? request = await LeaveService().fetchLeaveRequestById(
        widget.initialRequestId!,
      );
      if (!mounted) {
        return;
      }
      if (request != null) {
        setState(() {
          _applyEditingRequest(request);
          _isLoadingRequest = false;
        });
        _loadLeaveDuration();
        return;
      }
      setState(() {
        _isLoadingRequest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request is no longer available.')),
      );
      Navigator.of(context).pop(false);
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingRequest = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingRequest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load leave request.')),
      );
      Navigator.of(context).pop(false);
    }
  }

  void _applyEditingRequest(LeaveRequest request) {
    _editingRequest = request;
    _selectedType = request.type;
    _startDate = request.startDate;
    _endDate = request.endDate;
    _reasonController.text = request.reason;
  }

  Future<int> _calculateLeaveDuration() async {
    if (_usesBackend) {
      return LeaveService().countLeaveWorkingDays(
        startDate: _startDate,
        endDate: _endDate,
      );
    }
    return _weekdayDurationDays(_startDate, _endDate);
  }

  Future<void> _loadLeaveDuration() async {
    final int loadVersion = ++_durationLoadVersion;
    if (mounted) {
      setState(() {
        _isLoadingDuration = true;
      });
    }

    try {
      final int durationDays = await _calculateLeaveDuration();
      if (!mounted || loadVersion != _durationLoadVersion) {
        return;
      }
      setState(() {
        _durationDays = durationDays;
        _isLoadingDuration = false;
      });
    } catch (_) {
      if (!mounted || loadVersion != _durationLoadVersion) {
        return;
      }
      setState(() {
        _durationDays = _weekdayDurationDays(_startDate, _endDate);
        _isLoadingDuration = false;
      });
    }
  }

  Future<void> _loadAnnualLeaveBalance() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingBalance = true;
    });

    try {
      final AnnualLeaveBalance balance = _usesBackend
          ? await LeaveService().fetchAnnualLeaveBalance()
          : _mockAnnualLeaveBalance();
      if (!mounted) {
        return;
      }
      setState(() {
        _annualLeaveBalance = balance;
        _isLoadingBalance = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _annualLeaveBalance = const AnnualLeaveBalance(
          totalDays: LeaveService.defaultAnnualLeaveEntitlementDays,
          usedDays: 0,
          pendingDays: 0,
        );
        _isLoadingBalance = false;
      });
    }
  }

  AnnualLeaveBalance _mockAnnualLeaveBalance() {
    int usedDays = 0;
    int pendingDays = 0;
    for (final LeaveRequest request in _store.leaveRequests) {
      if (request.type != LeaveType.annualLeave) {
        continue;
      }
      final int durationDays =
          request.durationDays ??
          _weekdayDurationDays(request.startDate, request.endDate);
      switch (request.status) {
        case LeaveRequestStatus.approved:
          usedDays += durationDays;
          break;
        case LeaveRequestStatus.pendingApproval:
          pendingDays += durationDays;
          break;
        case LeaveRequestStatus.rejected:
          break;
      }
    }

    return AnnualLeaveBalance(
      totalDays: LeaveService.defaultAnnualLeaveEntitlementDays,
      usedDays: usedDays,
      pendingDays: pendingDays,
    );
  }

  Future<void> _pickStartDate() async {
    if (_isSubmitting) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime firstDate = today;
    final DateTime lastDate = DateTime(now.year + 2, 12, 31);
    final DateTime initialDate = _startDate.isBefore(firstDate)
        ? firstDate
        : _startDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
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
      _submitErrorMessage = null;
    });
    _loadLeaveDuration();
  }

  Future<void> _pickEndDate() async {
    if (_isSubmitting) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime firstDate = _startDate.isAfter(today) ? _startDate : today;
    final DateTime lastDate = DateTime(now.year + 2, 12, 31);
    final DateTime initialDate = _endDate.isBefore(firstDate)
        ? firstDate
        : _endDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
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
      _submitErrorMessage = null;
    });
    _loadLeaveDuration();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (_startDate.isBefore(today)) {
      setState(() {
        _submitErrorMessage = 'Start date cannot be in the past.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start date cannot be in the past.')),
      );
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      setState(() {
        _submitErrorMessage = 'End date cannot be before start date.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date.')),
      );
      return;
    }

    final int durationDays = await _calculateLeaveDuration();
    if (!mounted) {
      return;
    }
    if (durationDays < 1) {
      const String message =
          'The selected range contains no working days. Weekends and public holidays do not require leave.';
      setState(() {
        _durationDays = 0;
        _isLoadingDuration = false;
        _submitErrorMessage = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(message)));
      return;
    }

    setState(() {
      _durationDays = durationDays;
      _isLoadingDuration = false;
      _isSubmitting = true;
      _submitErrorMessage = null;
    });

    try {
      if (_usesBackend) {
        if (_isEditing) {
          await LeaveService().updatePendingLeaveRequest(
            requestId: _editingRequest!.id,
            type: _selectedType,
            startDate: _startDate,
            endDate: _endDate,
            reason: _reasonController.text.trim(),
          );
        } else {
          await LeaveService().submitLeaveRequest(
            type: _selectedType,
            startDate: _startDate,
            endDate: _endDate,
            reason: _reasonController.text.trim(),
          );
        }
      } else {
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
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = _friendlyLeaveSubmitError(error);
      setState(() {
        _isSubmitting = false;
        _submitErrorMessage = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
              child: _isLoadingRequest
                  ? const _LeaveFormLoadingState()
                  : Column(
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
                                children: LeaveType.values
                                    .map((LeaveType type) {
                                      return ChoiceChip(
                                        label: Text(type.label),
                                        selected: _selectedType == type,
                                        onSelected: _isSubmitting
                                            ? null
                                            : (_) {
                                                setState(() {
                                                  _selectedType = type;
                                                  _submitErrorMessage = null;
                                                });
                                                if (type ==
                                                    LeaveType.annualLeave) {
                                                  _loadAnnualLeaveBalance();
                                                }
                                              },
                                        labelStyle: PulseClockTextStyles
                                            .cardSubtitle
                                            .copyWith(
                                              color: _selectedType == type
                                                  ? PulseClockColors.surface
                                                  : PulseClockColors
                                                        .textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                        selectedColor:
                                            PulseClockColors.actionBlue,
                                        backgroundColor:
                                            PulseClockColors.surfaceMuted,
                                        side: BorderSide(
                                          color: _selectedType == type
                                              ? PulseClockColors.actionBlue
                                              : PulseClockColors.cardBorder,
                                        ),
                                        showCheckmark: false,
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                              if (_selectedType ==
                                  LeaveType.annualLeave) ...<Widget>[
                                const SizedBox(height: 12),
                                AnnualLeaveBalanceCard(
                                  balance: _annualLeaveBalance,
                                  isLoading: _isLoadingBalance,
                                ),
                              ],
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
                              DetailInfoRow(
                                label: 'Leave Duration',
                                value: _durationLabel,
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
                              if (_submitErrorMessage != null) ...<Widget>[
                                const SizedBox(height: 12),
                                _LeaveSubmitErrorMessage(
                                  message: _submitErrorMessage!,
                                ),
                              ],
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        PulseClockColors.actionBlue,
                                    foregroundColor: PulseClockColors.surface,
                                    disabledBackgroundColor: PulseClockColors
                                        .actionBlue
                                        .withOpacity(0.65),
                                    disabledForegroundColor:
                                        PulseClockColors.surface,
                                    textStyle: PulseClockTextStyles
                                        .primaryAction
                                        .copyWith(fontSize: 20),
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
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
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

class AnnualLeaveBalanceCard extends StatelessWidget {
  const AnnualLeaveBalanceCard({
    super.key,
    required this.balance,
    required this.isLoading,
  });

  final AnnualLeaveBalance balance;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final String pendingText = balance.pendingDays == 0
        ? 'No annual leave pending approval.'
        : '${balance.pendingDays} day${balance.pendingDays == 1 ? '' : 's'} pending approval. If approved: ${balance.projectedRemainingDays} day${balance.projectedRemainingDays == 1 ? '' : 's'} left.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PulseClockColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PulseClockColors.cardBorder),
      ),
      child: isLoading
          ? Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Checking annual leave balance...',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    color: PulseClockColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Annual Leave Balance',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    color: PulseClockColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${balance.remainingDays} of ${balance.totalDays} days remaining',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    color: PulseClockColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${balance.usedDays} day${balance.usedDays == 1 ? '' : 's'} approved/used.',
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pendingText,
                  style: PulseClockTextStyles.cardSubtitle.copyWith(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
    );
  }
}

class _LeaveSubmitErrorMessage extends StatelessWidget {
  const _LeaveSubmitErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF4F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3B6B6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFB42318),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                color: const Color(0xFF8A1F17),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveFormLoadingState extends StatelessWidget {
  const _LeaveFormLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(PulseClockColors.surface),
        ),
      ),
    );
  }
}

String _friendlyLeaveSubmitError(Object error) {
  if (error is StateError && error.message.isNotEmpty) {
    return error.message;
  }

  final String message = error.toString().toLowerCase();
  if (message.contains('attendance activity') ||
      message.contains('clock_in') ||
      message.contains('clock_out') ||
      message.contains('completed')) {
    return 'Leave cannot be requested for a date that already has attendance activity. Choose a date with no Clock In or Clock Out record.';
  }

  if (message.contains('no scheduled working days') ||
      message.contains('public holiday')) {
    return 'The selected range contains no working days. Weekends and public holidays do not require leave.';
  }

  if (message.contains('row-level security') ||
      message.contains('permission')) {
    return 'WorkPulse could not save this leave request because your account does not have permission for that action.';
  }

  return 'Unable to submit leave request. Please check the dates and try again.';
}

int _weekdayDurationDays(DateTime startDate, DateTime endDate) {
  final DateTime start = DateTime(
    startDate.year,
    startDate.month,
    startDate.day,
  );
  final DateTime end = DateTime(endDate.year, endDate.month, endDate.day);
  if (end.isBefore(start)) {
    return 0;
  }
  int count = 0;
  DateTime cursor = start;
  while (!cursor.isAfter(end)) {
    if (cursor.weekday >= DateTime.monday &&
        cursor.weekday <= DateTime.friday) {
      count += 1;
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  return count;
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
