// lib/screens/printer_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // SİZİN KULLANDIĞINIZ DOĞRU IMPORT YOLU
import '../models/printer_config.dart';
import '../services/printing_service.dart';
import '../services/cache_service.dart';
import '../models/discovered_printer.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({Key? key}) : super(key: key);

  @override
  _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isDiscovering = false;
  List<DiscoveredPrinter> _discoveredPrinters = [];
  List<PrinterConfig> _savedPrinters = [];
  final CacheService _cacheService = CacheService.instance;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final printers = _cacheService.getPrinters();
      if (mounted) {
        setState(() {
          _savedPrinters = printers;
        });
      }
    } catch (e) {
      if (mounted) {
        // AppLocalizations.of(context) kullanabilmek için context'in build edilmiş olması gerekir.
        // initState gibi yerlerde doğrudan kullanamayız, bu yüzden hatayı bir değişkende saklayıp build anında göstereceğiz.
        // Ancak bu metodda context'e erişimimiz var, bu yüzden sorun yok.
        setState(() {
          _errorMessage = AppLocalizations.of(context)!
              .printerSettingsErrorLoadingSavedPrinters(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addPrinter(PrinterConfig newPrinter) async {
    final l10n = AppLocalizations.of(context)!;
    if (_savedPrinters.any((p) => p.ipAddress == newPrinter.ipAddress)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.printerSettingsErrorIpExists)),
        );
      }
      return;
    }
    await _cacheService.savePrinter(newPrinter);
    _loadPrinters();
  }

  Future<void> _removePrinter(PrinterConfig printerToRemove) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final dialogL10n = AppLocalizations.of(ctx)!;
          return AlertDialog(
            title: Text(dialogL10n.printerSettingsDeleteTitle),
            content: Text(dialogL10n
                .printerSettingsDeleteConfirmation(printerToRemove.name)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(dialogL10n.dialogButtonCancel)),
              ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(dialogL10n.dialogButtonDelete),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.red)),
            ],
          );
        });

    if (confirm != true) return;

    await _cacheService.deletePrinter(printerToRemove.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.printerSettingsSuccessDeleted(printerToRemove.name)),
            backgroundColor: Colors.orangeAccent),
      );
    }
    _loadPrinters();
  }

  Future<void> _discoverPrinters() async {
    final l10n = AppLocalizations.of(context)!;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.printerSettingsErrorDiscoveryNotSupportedOnWeb),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() {
      _isDiscovering = true;
      _discoveredPrinters = [];
    });

    try {
      final printers = await PrintingService.discoverPrinters();
      if (mounted) {
        setState(() {
          _discoveredPrinters = printers;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(l10n.printerSettingsErrorDuringDiscovery(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _isDiscovering = false);
    }
  }

  Future<void> _testPrinter(PrinterConfig printer) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.printerSettingsInfoTesting(printer.name))),
    );
    try {
      final success = await PrintingService.testPrint(printer.ipAddress);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(success
                  ? l10n.printerSettingsSuccessTestPrint
                  : l10n.printerSettingsErrorTestPrintFailed),
              backgroundColor: success ? Colors.green : Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.printerSettingsErrorDuringTest(e.toString())),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddPrinterDialog({DiscoveredPrinter? discoveredDevice}) async {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: discoveredDevice?.name ?? '');
    final ipController = TextEditingController(text: discoveredDevice?.host ?? '');
    PrinterType? selectedType = PrinterType.kitchen;
    bool isDialogSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext)!;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(dialogL10n.dialogButtonCancel,
                      style: const TextStyle(color: Colors.white70))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade900),
                onPressed: isDialogSubmitting
                    ? null
                    : () {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isDialogSubmitting = true);
                          final newPrinter = PrinterConfig(
                            name: nameController.text,
                            ipAddress: ipController.text,
                            type: selectedType == PrinterType.kitchen
                                ? 'kitchen'
                                : 'receipt',
                          );
                          _addPrinter(newPrinter);
                          Navigator.of(context).pop();
                        }
                      },
                child: isDialogSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(dialogL10n.buttonSave),
              ),
            ],
            content: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade800.withOpacity(0.98),
                    Colors.blue.shade500.withOpacity(0.95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black38,
                      blurRadius: 10,
                      offset: Offset(0, 4))
                ],
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          discoveredDevice == null
                              ? dialogL10n.printerSettingsTitleAddManual
                              : dialogL10n.printerSettingsTitleSaveDiscovered,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: dialogL10n.printerSettingsLabelNameHint,
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white54),
                              borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? dialogL10n.printerSettingsValidatorNameEmpty
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ipController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: dialogL10n.printerSettingsLabelIpHint,
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white54),
                              borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return dialogL10n.printerSettingsValidatorIpEmpty;
                          }
                          final ipRegex =
                              RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
                          if (!ipRegex.hasMatch(value)) {
                            return dialogL10n.printerSettingsValidatorIpInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PrinterType>(
                        value: selectedType,
                        decoration: InputDecoration(
                          labelText: dialogL10n.printerSettingsLabelType,
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white54),
                              borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                        ),
                        dropdownColor: Colors.blue.shade800,
                        style: const TextStyle(color: Colors.white),
                        items: [
                          DropdownMenuItem(
                              value: PrinterType.kitchen,
                              child: Text(dialogL10n.printerSettingsTypeKitchen)),
                          DropdownMenuItem(
                              value: PrinterType.receipt,
                              child: Text(dialogL10n.printerSettingsTypeReceipt)),
                        ],
                        onChanged: (value) => selectedType = value,
                        validator: (value) => value == null
                            ? dialogL10n.printerSettingsValidatorTypeEmpty
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.printerSettingsTitle,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
        child: Column(
          children: [
            if (!kIsWeb)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: ElevatedButton.icon(
                  onPressed: _isDiscovering ? null : _discoverPrinters,
                  icon: _isDiscovering
                      ? Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white))
                      : const Icon(Icons.search),
                  label: Text(_isDiscovering
                      ? l10n.printerSettingsStateDiscovering
                      : l10n.printerSettingsButtonDiscover),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(45),
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadPrinters,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(_errorMessage,
                                style: const TextStyle(
                                    color: Colors.orangeAccent, fontSize: 16),
                                textAlign: TextAlign.center),
                          ))
                        : _savedPrinters.isEmpty &&
                                _discoveredPrinters.isEmpty
                            ? LayoutBuilder(
                                builder: (context, constraints) =>
                                    SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Container(
                                    height: constraints.maxHeight,
                                    alignment: Alignment.center,
                                    child: Text(
                                        l10n.printerSettingsNoPrintersFound,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16)),
                                  ),
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.all(16.0),
                                children: [
                                  if (_discoveredPrinters.isNotEmpty) ...[
                                    Text(l10n.printerSettingsHeaderDiscovered,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    ..._discoveredPrinters
                                        .map((printer) => Card(
                                              color: Colors.white
                                                  .withOpacity(0.85),
                                              child: ListTile(
                                                title: Text(printer.name),
                                                subtitle:
                                                    Text(printer.host),
                                                trailing: IconButton(
                                                  icon: const Icon(
                                                      Icons.add_circle,
                                                      color: Colors.green),
                                                  tooltip: l10n.printerSettingsTooltipSaveDiscovered,
                                                  onPressed: () =>
                                                      _showAddPrinterDialog(
                                                          discoveredDevice:
                                                              printer),
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                    const SizedBox(height: 24),
                                  ],
                                  if (_savedPrinters.isNotEmpty) ...[
                                    Text(l10n.printerSettingsHeaderSaved,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    ..._savedPrinters
                                        .map((printer) {
                                          final typeText = printer.printerTypeEnum == PrinterType.kitchen
                                            ? l10n.printerSettingsTypeKitchen
                                            : l10n.printerSettingsTypeReceipt;
                                          
                                          return Card(
                                            color: Colors.white
                                                .withOpacity(0.85),
                                            elevation: 3,
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 6),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        10)),
                                            child: ListTile(
                                              leading: Icon(
                                                printer.printerTypeEnum ==
                                                        PrinterType.kitchen
                                                    ? Icons.kitchen_outlined
                                                    : Icons
                                                        .receipt_long_outlined,
                                                color: Theme.of(context)
                                                    .primaryColorDark,
                                              ),
                                              title: Text(printer.name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              subtitle: Text(
                                                  '${printer.ipAddress}:${printer.port}\n${l10n.printerSettingsPrinterTypeLabel(typeText)}'),
                                              isThreeLine: true,
                                              trailing: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                      icon: Icon(
                                                          Icons
                                                              .print_outlined,
                                                          color: Colors
                                                              .blueGrey
                                                              .shade700),
                                                      tooltip: l10n.printerSettingsTooltipTestPrint,
                                                      onPressed: () =>
                                                          _testPrinter(
                                                              printer)),
                                                  IconButton(
                                                      icon: Icon(
                                                          Icons
                                                              .delete_outline,
                                                          color: Colors
                                                              .redAccent
                                                              .shade100),
                                                      tooltip: l10n.tooltipDelete,
                                                      onPressed: () =>
                                                          _removePrinter(
                                                              printer)),
                                                ],
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ],
                                ],
                              ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPrinterDialog(),
        icon: const Icon(Icons.add),
        label: Text(l10n.printerSettingsButtonAddManual),
        tooltip: l10n.printerSettingsTooltipAddManual,
      ),
    );
  }
}