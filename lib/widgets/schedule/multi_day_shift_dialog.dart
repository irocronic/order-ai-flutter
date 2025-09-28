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
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.9;

    return AlertDialog(
      title: Text(
        l10n.multiDayShiftDialogTitle(widget.selectedDates.length.toString()),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seçili tarihler bölümü
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.multiDayShiftDialogSelectedDatesLabel,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4.0,
                        runSpacing: 4.0,
                        children: widget.selectedDates.map((date) {
                          return Chip(
                            label: Text(
                              DateFormat('d MMM', l10n.localeName).format(date),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Personel seçimi bölümü
                Text(
                  l10n.multiDayShiftDialogStep1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: widget.staffList.isEmpty
                      ? Center(
                          child: Text(
                            'Henüz personel bulunamadı',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        )
                      : Scrollbar(
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            itemCount: widget.staffList.length,
                            itemBuilder: (context, index) {
                              final staff = widget.staffList[index];
                              final staffId = staff['id'] as int;
                              final firstName = staff['first_name']?.toString().trim() ?? '';
                              final lastName = staff['last_name']?.toString().trim() ?? '';
                              final username = staff['username']?.toString().trim() ?? '';
                              
                              final fullName = '$firstName $lastName'.trim();
                              final displayName = fullName.isNotEmpty ? fullName : username;

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                                child: CheckboxListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  title: Text(
                                    displayName.isNotEmpty ? displayName : 'Bilinmeyen Kullanıcı',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                              );
                            },
                          ),
                        ),
                ),
                
                const SizedBox(height: 16),
                
                // Vardiya seçimi bölümü
                Text(
                  l10n.multiDayShiftDialogStep2,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Dropdown için Flexible kullanarak overflow'u önliyoruz
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<int>(
                    value: _selectedShiftId,
                    hint: Text(
                      l10n.multiDayShiftDialogHint,
                      overflow: TextOverflow.ellipsis,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    isExpanded: true, // Bu önemli: dropdown'ın genişliğini konteynerine uyarlar
                    items: widget.shiftTemplates.map((shift) {
                      return DropdownMenuItem<int>(
                        value: shift.id,
                        child: Flexible(
                          child: Text(
                            shift.name,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
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
                ),
                
                const SizedBox(height: 8),
                
                // Seçim durumu göstergesi
                if (_selectedStaffIds.isNotEmpty || _selectedShiftId != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedStaffIds.isNotEmpty)
                          Text(
                            'Seçili Personel: ${_selectedStaffIds.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (_selectedShiftId != null)
                          Text(
                            'Seçili Vardiya: ${widget.shiftTemplates.firstWhere((s) => s.id == _selectedShiftId).name}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.dialogButtonCancel),
        ),
        const SizedBox(width: 8),
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