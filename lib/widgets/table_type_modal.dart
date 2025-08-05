// lib/widgets/table_type_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Masa tipi seçimi (tekil/bölünmüş) ve bölünmüş masa sahiplerini girmek için modal.
class TableTypeModal extends StatefulWidget {
  final Function(bool isSplit, List<String> tableOwners) onTypeSelected;

  const TableTypeModal({
    Key? key,
    required this.onTypeSelected,
  }) : super(key: key);

  @override
  _TableTypeModalState createState() => _TableTypeModalState();
}

class _TableTypeModalState extends State<TableTypeModal> {
  bool isSplitTable = false;
  List<TextEditingController> controllers = [TextEditingController(), TextEditingController()];

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF283593).withOpacity(0.85),
              const Color(0xFF455A64).withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 2)),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.dialogTableTypeTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.dialogTableTypeContent,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSplitTable == false ? Colors.white : Colors.white.withOpacity(0.8),
                      foregroundColor: isSplitTable == false ? Colors.blue : Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() {
                        isSplitTable = false;
                        controllers.clear();
                        controllers.add(TextEditingController());
                      });
                    },
                    child: Text(l10n.newOrderTableTypeSingle),
                  ),
                    ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSplitTable == true ? Colors.white : Colors.white.withOpacity(0.8),
                      foregroundColor: isSplitTable == true ? Colors.blue : Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                        setState(() {
                          isSplitTable = true;
                          if(controllers.isEmpty) {
                            controllers.add(TextEditingController());
                            controllers.add(TextEditingController());
                          } else if (controllers.length == 1) {
                            controllers.add(TextEditingController());
                          }
                        });
                    },
                    child: Text(l10n.newOrderTableTypeSplit),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isSplitTable) ...[
                Text(l10n.tableTypeModalOwnersTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                  ...List.generate(controllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: TextField(
                        controller: controllers[index],
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: l10n.dialogTableOwnersHint((index + 1).toString()),
                          labelStyle: const TextStyle(color: Colors.black54),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    );
                  }),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      controllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(l10n.dialogTableOwnersAddButton, style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.dialogButtonCancel, style: const TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        shadowColor: Colors.black.withOpacity(0.25),
                        elevation: 4,
                      ),
                    onPressed: () {
                      if (isSplitTable && controllers.where((ctrl) => ctrl.text.trim().isNotEmpty).length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.newOrderErrorMinOwnersForSplit)),
                          );
                          return;
                      }
                      List<String> tableOwners = controllers
                          .map((ctrl) => ctrl.text.trim())
                          .where((name) => name.isNotEmpty)
                          .toList();

                      widget.onTypeSelected(isSplitTable, tableOwners);
                      Navigator.of(context).pop();
                    },
                    child: Text(l10n.continueButtonText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}