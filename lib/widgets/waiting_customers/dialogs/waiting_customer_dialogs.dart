// lib/widgets/waiting_customers/dialogs/waiting_customer_dialogs.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextInputFormatter için
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class WaitingCustomerDialogs {
  static Future<void> showEditCustomerDialog({
    required BuildContext context,
    required dynamic customer,
    required Future<void> Function(
      int customerId,
      String name,
      String phone,
      bool isWaiting,
      int partySize,
      String notes
    ) onConfirm,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController editNameController = TextEditingController(text: customer['name']?.toString() ?? '');
    final TextEditingController editPhoneController = TextEditingController(text: customer['phone']?.toString() ?? '');
    final TextEditingController editPartySizeController = TextEditingController(text: customer['party_size']?.toString() ?? '1');
    final TextEditingController editNotesController = TextEditingController(text: customer['notes']?.toString() ?? '');
    bool isWaiting = customer['is_waiting'] as bool? ?? true;
    final GlobalKey<FormState> formKeyDialog = GlobalKey<FormState>();
    bool isDialogSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade800.withOpacity(0.95),
                      Colors.blue.shade500.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKeyDialog,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.waitingCustomerDialogEditTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: editNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: l10n.waitingCustomerDialogNameLabel,
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white54), borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white), borderRadius: BorderRadius.circular(8)),
                            filled: true, fillColor: Colors.white.withOpacity(0.1),
                          ),
                          validator: (value) => (value == null || value.trim().isEmpty) ? l10n.waitingCustomerDialogNameValidator : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: editPhoneController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: l10n.waitingCustomerDialogPhoneLabel,
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white54), borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white), borderRadius: BorderRadius.circular(8)),
                            filled: true, fillColor: Colors.white.withOpacity(0.1),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: editPartySizeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: l10n.waitingCustomerDialogPartySizeLabel,
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white54), borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white), borderRadius: BorderRadius.circular(8)),
                            filled: true, fillColor: Colors.white.withOpacity(0.1),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return l10n.waitingCustomerDialogPartySizeValidatorRequired;
                            final intValue = int.tryParse(value.trim());
                            if (intValue == null || intValue <= 0) return l10n.waitingCustomerDialogPartySizeValidatorPositive;
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: editNotesController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: l10n.waitingCustomerDialogNotesLabel,
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white54), borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white), borderRadius: BorderRadius.circular(8)),
                            filled: true, fillColor: Colors.white.withOpacity(0.1),
                          ),
                          maxLines: 2,
                        ),
                        SwitchListTile(
                          title: Text(l10n.waitingCustomerDialogWaitingLabel, style: const TextStyle(color: Colors.white)),
                          value: isWaiting,
                          onChanged: (value) {
                            setStateDialog(() {
                              isWaiting = value;
                            });
                          },
                          activeColor: Colors.greenAccent,
                          inactiveThumbColor: Colors.grey,
                          tileColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isDialogSubmitting ? null : () => Navigator.pop(dialogContext),
                              child: Text(l10n.dialogButtonCancel, style: const TextStyle(color: Colors.white70)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.blue.shade800,
                                shadowColor: Colors.black.withOpacity(0.25),
                                elevation: 4,
                              ),
                              onPressed: isDialogSubmitting ? null : () async {
                                if (formKeyDialog.currentState!.validate()) {
                                  setStateDialog(() => isDialogSubmitting = true);
                                  int partySize = int.tryParse(editPartySizeController.text.trim()) ?? 1;
                                  
                                  await onConfirm(
                                    customer['id'] as int,
                                    editNameController.text.trim(),
                                    editPhoneController.text.trim(),
                                    isWaiting,
                                    partySize,
                                    editNotesController.text.trim(),
                                  );

                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                }
                              },
                              child: isDialogSubmitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(l10n.buttonSave),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    editNameController.dispose();
    editPhoneController.dispose();
    editPartySizeController.dispose();
    editNotesController.dispose();
  }

  static Future<void> showDeleteConfirmationDialog({
    required BuildContext context,
    required int customerId,
    required Future<void> Function(int customerId) onConfirm,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ Colors.red.shade700.withOpacity(0.9), Colors.red.shade400.withOpacity(0.85)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [ BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.waitingCustomerDialogDeleteTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.waitingCustomerDialogDeleteContent(customerId.toString()),
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(l10n.dialogButtonNo, style: const TextStyle(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red.shade700),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(l10n.dialogButtonDeleteConfirm),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirm == true) {
      await onConfirm(customerId);
    }
  }
}