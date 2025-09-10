// lib/screens/supplier_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/supplier.dart';
import '../services/procurement_service.dart';
import '../services/user_session.dart';

class SupplierManagementScreen extends StatefulWidget {
  const SupplierManagementScreen({Key? key}) : super(key: key);

  @override
  _SupplierManagementScreenState createState() =>
      _SupplierManagementScreenState();
}

class _SupplierManagementScreenState extends State<SupplierManagementScreen> {
  late Future<List<Supplier>> _suppliersFuture;

  @override
  void initState() {
    super.initState();
    _refreshSuppliers();
  }

  void _refreshSuppliers() {
    if (!mounted) return;
    setState(() {
      _suppliersFuture = ProcurementService.fetchSuppliers(UserSession.token);
    });
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.supplierDeleteTitle),
        content: Text(l10n.supplierDeleteConfirmation(supplier.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.dialogButtonCancel)),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.dialogButtonDeleteConfirm),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ProcurementService.deleteSupplier(UserSession.token, supplier.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.supplierDeleteSuccess(supplier.name)), // DÜZELTME BURADA
            backgroundColor: Colors.green));
        _refreshSuppliers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.errorGeneral(e.toString())),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showAddEditSupplierDialog({Supplier? supplier}) async {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: supplier?.name ?? '');
    final contactController =
        TextEditingController(text: supplier?.contactPerson ?? '');
    final emailController = TextEditingController(text: supplier?.email ?? '');
    final phoneController = TextEditingController(text: supplier?.phone ?? '');
    final addressController =
        TextEditingController(text: supplier?.address ?? '');
    bool isDialogSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(supplier == null
                  ? l10n.supplierAddDialogTitle
                  : l10n.supplierEditDialogTitle(supplier.name)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration:
                            InputDecoration(labelText: l10n.supplierNameLabel),
                        validator: (value) => (value == null || value.isEmpty)
                            ? l10n.validatorRequiredField
                            : null,
                      ),
                      TextFormField(
                        controller: contactController,
                        decoration: InputDecoration(
                            labelText: l10n.supplierContactPersonLabel),
                      ),
                      TextFormField(
                        controller: emailController,
                        decoration:
                            InputDecoration(labelText: l10n.emailLabel),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      TextFormField(
                        controller: phoneController,
                        decoration:
                            InputDecoration(labelText: l10n.phoneLabel),
                        keyboardType: TextInputType.phone,
                      ),
                      TextFormField(
                        controller: addressController,
                        decoration:
                            InputDecoration(labelText: l10n.addressLabel),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.dialogButtonCancel),
                ),
                ElevatedButton(
                  onPressed: isDialogSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isDialogSubmitting = true);
                            try {
                              final data = {
                                'name': nameController.text.trim(),
                                'contact_person': contactController.text.trim(),
                                'email': emailController.text.trim(),
                                'phone': phoneController.text.trim(),
                                'address': addressController.text.trim(),
                              };
                              if (supplier == null) {
                                await ProcurementService.createSupplier(
                                    UserSession.token, data);
                              } else {
                                await ProcurementService.updateSupplier(
                                    UserSession.token, supplier.id, data);
                              }
                              Navigator.pop(dialogContext);
                              _refreshSuppliers();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text(l10n.errorGeneral(e.toString())),
                                        backgroundColor: Colors.red));
                              }
                            } finally {
                              if (mounted) {
                                setDialogState(
                                    () => isDialogSubmitting = false);
                              }
                            }
                          }
                        },
                  child: isDialogSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.buttonSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supplierManagementTitle,
            style: const TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.8)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<List<Supplier>>(
          future: _suppliersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text(l10n.errorGeneral(snapshot.error.toString()),
                      style: const TextStyle(color: Colors.orangeAccent)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                  child: Text(l10n.supplierNoItems,
                      style: const TextStyle(color: Colors.white70)));
            }

            final suppliers = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: suppliers.length,
              itemBuilder: (context, index) {
                final supplier = suppliers[index];
                return Card(
                  color: Colors.white.withOpacity(0.9),
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping, color: Colors.blueGrey),
                    title: Text(supplier.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        supplier.contactPerson ?? l10n.supplierNoContactPerson),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showAddEditSupplierDialog(supplier: supplier);
                        } else if (value == 'delete') {
                          _deleteSupplier(supplier);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(l10n.tooltipEdit),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.tooltipDelete, style: const TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSupplierDialog(),
        icon: const Icon(Icons.add),
        label: Text(l10n.supplierAddButton),
      ),
    );
  }
}