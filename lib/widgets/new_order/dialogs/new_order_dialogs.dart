// lib/widgets/new_order/dialogs/new_order_dialogs.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../table_type_modal.dart'; // TableTypeModal'ı import et

/// NewOrderScreen için kullanılan dialogları gösteren yardımcı sınıf.
class NewOrderDialogs {
  /// Masa tipi seçimi (tekil/bölünmüş) dialoğunu gösterir.
  static Future<void> promptTableType({
    required BuildContext context,
    required Function(bool isSplit, List<String> tableOwners) onSelected,
    required Function() onCancel,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Dışarı tıklayınca kapanmasın
      builder: (dialogContext) => TableTypeModal(
        onTypeSelected: (isSplit, owners) {
          onSelected(isSplit, owners);
        },
      ),
    );
    // Eğer showDialog sonrası isSplitTable hala null ise kullanıcı iptal etmiş demektir.
    // Bu kontrol ve aksiyon Screen tarafında yapılmalı.
  }

  /// Bölünmüş masa için masa sahibi adlarının girileceği dialoğu gösterir.
  static Future<void> promptTableOwners({
    required BuildContext context,
    required List<String> initialOwners,
    required Function(List<String> owners) onConfirm,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    List<TextEditingController> controllers = initialOwners.isNotEmpty
        ? initialOwners.map((name) => TextEditingController(text: name)).toList()
        : [TextEditingController(), TextEditingController()]; // En az 2 ile başla

    // Dispose edilecek controller listesi
    List<TextEditingController> controllersToDispose = List.from(controllers);

    await showDialog(
      context: context,
      barrierDismissible: false, // Genellikle sahip girişi zorunlu olmalı
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white.withOpacity(0.9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(l10n.dialogTableOwnersTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.newOrderErrorMinOwnersForSplit),
                    const SizedBox(height: 8),
                    ...List.generate(controllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: TextField(
                          controller: controllers[index],
                          decoration: InputDecoration(
                            labelText: l10n.dialogTableOwnersHint((index + 1).toString()),
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () {
                        final newController = TextEditingController();
                        setModalState(() {
                          controllers.add(newController);
                          controllersToDispose.add(newController); // Dispose listesine ekle
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: Text(l10n.dialogTableOwnersAddButton),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext), // Sadece dialogu kapatır
                  child: Text(l10n.dialogButtonCancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    List<String> currentOwners = controllers
                        .map((ctrl) => ctrl.text.trim())
                        .where((name) => name.isNotEmpty)
                        .toList();
                    if (currentOwners.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.newOrderErrorMinOwnersForSplit)),
                      );
                      return;
                    }
                    // Controller'daki metodu çağır
                    onConfirm(currentOwners);
                    Navigator.pop(dialogContext); // Dialogu kapat
                  },
                  child: Text(l10n.buttonSave),
                ),
              ],
            );
          },
        );
      },
    );

    // Dialog kapandıktan sonra oluşturulan controller'ları dispose et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var controller in controllersToDispose) {
        // Kullanıcı tarafından silinmemişse dispose et
        if (controllers.contains(controller)) {
          controller.dispose();
        }
      }
    });
  }
}