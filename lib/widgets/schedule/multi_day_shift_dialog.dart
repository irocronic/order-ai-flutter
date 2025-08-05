// lib/widgets/schedule/multi_day_shift_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/shift_model.dart';

class MultiDayShiftDialog extends StatefulWidget {
  final List<DateTime> selectedDates;
  final List<dynamic> staffList;
  final List<Shift> shiftTemplates;
  final Function(List<int> staffIds, int shiftId) onConfirm;

  const MultiDayShiftDialog({
    Key? key,
    required this.selectedDates,
    required this.staffList,
    required this.shiftTemplates,
    required this.onConfirm,
  }) : super(key: key);

  @override
  _MultiDayShiftDialogState createState() => _MultiDayShiftDialogState();
}

class _MultiDayShiftDialogState extends State<MultiDayShiftDialog> {
  final Set<int> _selectedStaffIds = {};
  int? _selectedShiftId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.multiDayShiftDialogTitle(widget.selectedDates.length.toString())),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.multiDayShiftDialogSelectedDatesLabel +
                    widget.selectedDates
                        .map((d) => DateFormat('d MMM', l10n.localeName).format(d))
                        .join(', '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 20),
              Text(l10n.multiDayShiftDialogStep1, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200, // Yüksekliği sınırlı tutarak kaydırılabilir yap
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.staffList.length,
                  itemBuilder: (context, index) {
                    final staff = widget.staffList[index];
                    final staffId = staff['id'] as int;
                    final fullName =
                        "${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}"
                            .trim();
                    final displayName =
                        fullName.isNotEmpty ? fullName : staff['username'];

                    return CheckboxListTile(
                      title: Text(displayName),
                      value: _selectedStaffIds.contains(staffId),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedStaffIds.add(staffId);
                          } else {
                            _selectedStaffIds.remove(staffId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.multiDayShiftDialogStep2, style: const TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<int>(
                value: _selectedShiftId,
                hint: Text(l10n.multiDayShiftDialogHint),
                items: widget.shiftTemplates.map((shift) {
                  return DropdownMenuItem<int>(
                    value: shift.id,
                    child: Text(shift.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedShiftId = value;
                  });
                },
                validator: (value) =>
                    value == null ? l10n.multiDayShiftDialogValidator : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.dialogButtonCancel),
        ),
        ElevatedButton(
          onPressed: (_selectedStaffIds.isEmpty || _selectedShiftId == null)
              ? null
              : () {
                  widget.onConfirm(_selectedStaffIds.toList(), _selectedShiftId!);
                  Navigator.of(context).pop();
                },
          child: Text(l10n.buttonAssign),
        ),
      ],
    );
  }
}