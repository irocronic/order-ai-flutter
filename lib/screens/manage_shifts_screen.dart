// lib/screens/manage_shifts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/schedule_service.dart';
import '../models/shift_model.dart';
import '../services/user_session.dart';
import 'subscription_screen.dart';

class ManageShiftsScreen extends StatefulWidget {
  const ManageShiftsScreen({Key? key}) : super(key: key);

  @override
  _ManageShiftsScreenState createState() => _ManageShiftsScreenState();
}

class _ManageShiftsScreenState extends State<ManageShiftsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Shift> _shifts = [];

  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  Future<void> _fetchShifts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final shifts = await ScheduleService.fetchShifts(UserSession.token);
      if (mounted) setState(() => _shifts = shifts);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteShift(Shift shift) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.manageShiftsDeleteDialogTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        content: Text(l10n.manageShiftsDeleteDialogContent(shift.name), style: const TextStyle(color: Colors.blueGrey)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
            child: Text(l10n.dialogButtonCancel),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.dialogButtonDelete, style: const TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ScheduleService.deleteShift(UserSession.token, shift.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.manageShiftsSuccessDelete(shift.name), style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ),
      );
      _fetchShifts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorGeneral(e.toString()), style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAddEditShiftDialog({Shift? shift}) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: shift?.name ?? '');
    TimeOfDay startTime = shift?.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = shift?.endTime ?? const TimeOfDay(hour: 17, minute: 0);
    Color pickerColor = shift?.color ?? Colors.blue;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          final dialogL10n = AppLocalizations.of(context)!;
          return AlertDialog(
            title: Text(
              shift == null ? dialogL10n.manageShiftsAddDialogTitle : dialogL10n.manageShiftsEditDialogTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: dialogL10n.manageShiftsShiftNameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(dialogL10n.manageShiftsStartTimeLabel(startTime.format(context)), style: const TextStyle(color: Colors.blueGrey)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
                      child: Text(dialogL10n.manageShiftsSelectButton, style: const TextStyle(color: Colors.white)),
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: startTime);
                        if (picked != null) setDialogState(() => startTime = picked);
                      },
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(dialogL10n.manageShiftsEndTimeLabel(endTime.format(context)), style: const TextStyle(color: Colors.blueGrey)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
                      child: Text(dialogL10n.manageShiftsSelectButton, style: const TextStyle(color: Colors.white)),
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: endTime);
                        if (picked != null) setDialogState(() => endTime = picked);
                      },
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Text(dialogL10n.manageShiftsColorLabel, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  BlockPicker(
                    pickerColor: pickerColor,
                    onColorChanged: (color) => setDialogState(() => pickerColor = color),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                child: Text(dialogL10n.dialogButtonCancel),
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: Text(dialogL10n.buttonSave, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  try {
                    if (shift == null) {
                      await ScheduleService.createShift(UserSession.token,
                          name: nameController.text, startTime: startTime, endTime: endTime, color: pickerColor);
                    } else {
                      await ScheduleService.updateShift(UserSession.token, shift.id,
                          name: nameController.text, startTime: startTime, endTime: endTime, color: pickerColor);
                    }
                    Navigator.of(ctx).pop(true);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(dialogL10n.errorGeneral(e.toString()), style: const TextStyle(color: Colors.white)),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          );
        });
      },
    );
    if (result == true) {
      _fetchShifts();
    }
  }

  // +++ GÜNCELLENMİŞ VARDİYA KARTI WIDGET'I +++
  Widget _buildShiftCard(Shift shift, AppLocalizations l10n) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        onTap: () => _showAddEditShiftDialog(shift: shift),
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // Align to top
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: shift.color,
                child: Text(
                  shift.name.isNotEmpty ? shift.name.substring(0, 1).toUpperCase() : 'V',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                ),
              ),
              const SizedBox(height: 12),
              // Make the text part scrollable if it gets too long
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shift.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${shift.startTime.format(context)} - ${shift.endTime.format(context)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              // Spacer is removed, buttons are now at the bottom
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 20),
                    tooltip: l10n.tooltipEdit,
                    onPressed: () => _showAddEditShiftDialog(shift: shift),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: l10n.tooltipDelete,
                    onPressed: () => _deleteShift(shift),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageShiftsScreenTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF283593), Color(0xFF455A64)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.lightBlueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _errorMessage.isNotEmpty
                ? Center(child: Text(l10n.errorGeneral(_errorMessage), style: const TextStyle(color: Colors.red)))
                : RefreshIndicator(
                    onRefresh: _fetchShifts,
                    child: _shifts.isEmpty
                        ? Center(child: Text(l10n.manageShiftsNoShiftsFound, style: const TextStyle(color: Colors.white70)))
                        : GridView.builder(
                            padding: const EdgeInsets.all(16.0),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200,
                                childAspectRatio: 0.9,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16
                            ),
                            itemCount: _shifts.length,
                            itemBuilder: (ctx, index) {
                              final shift = _shifts[index];
                              return _buildShiftCard(shift, l10n);
                            },
                          ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditShiftDialog(),
        child: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue,
        tooltip: l10n.manageShiftsTooltipAdd,
      ),
    );
  }
}