import 'package:flutter/material.dart';
import 'package:pulseclock/features/attendance/location/office_location_service.dart';
import 'package:pulseclock/pulseclock/styles.dart';

class OfficePicker extends StatefulWidget {
  const OfficePicker({
    required this.offices,
    required this.selectedId,
    super.key,
  });

  final List<OfficeLocation> offices;
  final String? selectedId;

  @override
  State<OfficePicker> createState() => _OfficePickerState();
}

class _OfficePickerState extends State<OfficePicker> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<OfficeLocation> get _filteredOffices {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.offices;
    return widget.offices
        .where((OfficeLocation office) {
          return <String>[
            office.officeName,
            office.province ?? '',
            office.district ?? '',
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<OfficeLocation> offices = _filteredOffices;
    final double keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final double availableHeight =
        MediaQuery.sizeOf(context).height - keyboardHeight;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 14, 18, keyboardHeight + 14),
        child: SizedBox(
          height: availableHeight * 0.68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PulseClockColors.cardBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Select Usual Work Site',
                style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search office, province, or district',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: PulseClockColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: PulseClockColors.cardBorder,
                    ),
                  ),
                ),
                onChanged: (String value) => setState(() => _query = value),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.location_off_outlined),
                      title: const Text('No Usual Work Site'),
                      trailing: widget.selectedId == null
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: PulseClockColors.actionBlue,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                    const Divider(height: 1),
                    if (offices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'No work sites match your search.',
                          textAlign: TextAlign.center,
                          style: PulseClockTextStyles.cardSubtitle,
                        ),
                      )
                    else
                      ...offices.map(
                        (OfficeLocation office) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(
                            office.officeName,
                            style: PulseClockTextStyles.cardSubtitle.copyWith(
                              color: PulseClockColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            <String>[
                              if (office.district?.isNotEmpty == true)
                                '${office.district} District',
                              if (office.province?.isNotEmpty == true)
                                office.province!,
                            ].join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PulseClockTextStyles.cardSubtitle.copyWith(
                              fontSize: 12,
                            ),
                          ),
                          trailing: widget.selectedId == office.id
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: PulseClockColors.actionBlue,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(office.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
