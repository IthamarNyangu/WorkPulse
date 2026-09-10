import 'package:flutter/material.dart';
import 'package:pulseclock/features/employees/data/employee_management_service.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

class JobTitleManagementScreen extends StatefulWidget {
  const JobTitleManagementScreen({super.key});

  @override
  State<JobTitleManagementScreen> createState() =>
      _JobTitleManagementScreenState();
}

class _JobTitleManagementScreenState extends State<JobTitleManagementScreen> {
  final EmployeeManagementService _service = EmployeeManagementService();
  bool _isLoading = true;
  String? _errorMessage;
  List<WorkPulseJobTitle> _jobTitles = const <WorkPulseJobTitle>[];

  @override
  void initState() {
    super.initState();
    _loadJobTitles();
  }

  Future<void> _loadJobTitles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final List<WorkPulseJobTitle> jobTitles = await _service.fetchJobTitles();
      if (!mounted) return;
      setState(() {
        _jobTitles = jobTitles;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load job titles right now.';
      });
    }
  }

  Future<void> _openDialog({WorkPulseJobTitle? jobTitle}) async {
    final TextEditingController controller = TextEditingController(
      text: jobTitle?.name ?? '',
    );
    bool isActive = jobTitle?.isActive ?? true;
    bool isSaving = false;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          backgroundColor: PulseClockColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            jobTitle == null ? 'Add Job Title' : 'Edit Job Title',
            style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Job Title',
                  counterText: '',
                  filled: true,
                  fillColor: PulseClockColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (jobTitle != null)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active Job Title'),
                  value: isActive,
                  activeTrackColor: PulseClockColors.actionBlue,
                  onChanged: (bool value) => setDialogState(() => isActive = value),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final String name = controller.text.trim();
                      if (name.length < 2) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Job title must contain at least 2 characters.')),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        if (jobTitle == null) {
                          await _service.createJobTitle(name);
                        } else {
                          await _service.updateJobTitle(
                            jobTitle: jobTitle,
                            name: name,
                            isActive: isActive,
                          );
                        }
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                      } catch (_) {
                        if (!mounted) return;
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Unable to save this job title.')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: PulseClockColors.actionBlue,
                foregroundColor: PulseClockColors.surface,
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: PulseClockColors.surface))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == true && mounted) await _loadJobTitles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        title: const Text('Job Titles'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDialog(),
        backgroundColor: PulseClockColors.actionBlue,
        foregroundColor: PulseClockColors.surface,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Job Title'),
      ),
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [PulseClockColors.appBackground, PulseClockColors.appBackgroundDeep],
          ),
        ),
        child: SafeArea(top: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: PulseClockColors.onBackgroundPrimary));
    if (_errorMessage != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(20), child: SurfaceCard(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_errorMessage!, style: PulseClockTextStyles.cardSubtitle), TextButton(onPressed: _loadJobTitles, child: const Text('Retry'))]))));
    }
    if (_jobTitles.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: SurfaceCard(child: Text('No job titles have been added yet.', textAlign: TextAlign.center))));
    }
    return RefreshIndicator(
      onRefresh: _loadJobTitles,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
        itemCount: _jobTitles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 9),
        itemBuilder: (BuildContext context, int index) {
          final WorkPulseJobTitle item = _jobTitles[index];
          return Material(
            color: PulseClockColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _openDialog(jobTitle: item),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                child: Row(children: [
                  Expanded(child: Text(item.name, style: PulseClockTextStyles.cardSubtitle.copyWith(color: PulseClockColors.textPrimary, fontWeight: FontWeight.w800))),
                  Text(item.isActive ? 'Active' : 'Inactive', style: PulseClockTextStyles.cardSubtitle.copyWith(fontSize: 11, fontWeight: FontWeight.w800, color: item.isActive ? PulseClockColors.statusOnDutyAccent : PulseClockColors.statusOffDutyAccent)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: PulseClockColors.textSecondary),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
