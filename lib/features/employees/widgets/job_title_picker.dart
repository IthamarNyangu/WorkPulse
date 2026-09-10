import 'package:flutter/material.dart';
import 'package:pulseclock/features/employees/data/employee_management_service.dart';
import 'package:pulseclock/pulseclock/styles.dart';

class JobTitlePicker extends StatefulWidget {
  const JobTitlePicker({
    required this.jobTitles,
    required this.selectedName,
    this.allowEmpty = false,
    super.key,
  });

  final List<WorkPulseJobTitle> jobTitles;
  final String? selectedName;
  final bool allowEmpty;

  @override
  State<JobTitlePicker> createState() => _JobTitlePickerState();
}

class _JobTitlePickerState extends State<JobTitlePicker> {
  String _query = '';

  List<WorkPulseJobTitle> get _filteredTitles {
    final String query = _query.trim().toLowerCase();
    return widget.jobTitles
        .where(
          (WorkPulseJobTitle title) =>
              title.isActive || title.name == widget.selectedName,
        )
        .where(
          (WorkPulseJobTitle title) =>
              query.isEmpty || title.name.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Job Title',
                style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: (String value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search job titles',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: PulseClockColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (widget.allowEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.remove_circle_outline_rounded),
                  title: const Text('No Job Title'),
                  onTap: () => Navigator.of(context).pop(''),
                ),
              Expanded(
                child: _filteredTitles.isEmpty
                    ? const Center(child: Text('No matching job titles.'))
                    : ListView.separated(
                        itemCount: _filteredTitles.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final WorkPulseJobTitle title =
                              _filteredTitles[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(title.name),
                            trailing: title.name == widget.selectedName
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: PulseClockColors.actionBlue,
                                  )
                                : title.isActive
                                ? null
                                : const Text('Inactive'),
                            onTap: () => Navigator.of(context).pop(title.name),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
