// lib/screens/table_layout_screen.dart (GÜNCELLENMİŞ VE DUYARLI VERSİYON)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_layout_provider.dart';
import '../widgets/table_layout/layout_canvas.dart';
import '../widgets/table_layout/table_palette.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/table_model.dart';

class TableLayoutScreen extends StatefulWidget {
  const TableLayoutScreen({Key? key}) : super(key: key);

  @override
  State<TableLayoutScreen> createState() => _TableLayoutScreenState();
}

class _TableLayoutScreenState extends State<TableLayoutScreen> {
  bool _isPanelVisible = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ChangeNotifierProvider(
      create: (_) => TableLayoutProvider(),
      child: Consumer<TableLayoutProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.tableLayoutScreenTitle, style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.blue.shade900,
              actions: [
                IconButton(
                  icon: Icon(
                    _isPanelVisible ? Icons.view_quilt_outlined : Icons.view_day_outlined,
                    color: Colors.white,
                  ),
                  tooltip: _isPanelVisible ? "Eleman Panelini Gizle" : "Eleman Panelini Göster",
                  onPressed: () {
                    setState(() {
                      _isPanelVisible = !_isPanelVisible;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    provider.isGridVisible ? Icons.grid_on_outlined : Icons.grid_off_outlined,
                    color: provider.isGridVisible ? Colors.white : Colors.white54,
                  ),
                  tooltip: l10n.tableLayoutToggleGrid,
                  onPressed: () {
                    context.read<TableLayoutProvider>().toggleGridSnapping();
                  },
                ),
                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.save, color: Colors.white),
                    tooltip: l10n.buttonSaveChanges,
                    onPressed: () async {
                      await provider.saveLayout();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.errorMessage.isEmpty ? l10n.tableLayoutSuccessSave : l10n.tableLayoutErrorSave),
                            backgroundColor: provider.errorMessage.isEmpty ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
            floatingActionButton: provider.selectedItem != null
                ? FloatingActionButton.extended(
                    onPressed: () {
                      context.read<TableLayoutProvider>().deleteSelectedItem();
                    },
                    backgroundColor: Colors.redAccent,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: Text(
                      provider.selectedItem is TableModel
                          ? "Masayı Plana Geri Al"
                          : "Öğeyi Sil",
                    ),
                  )
                : null,
            body: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.errorMessage.isNotEmpty
                    ? Center(child: Text(provider.errorMessage))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          // Geniş ekran (Tablet/Web) yerleşimi
                          if (constraints.maxWidth > 700) {
                            return Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  width: _isPanelVisible ? 250 : 0,
                                  child: const ClipRect(
                                    child: TablePalette(
                                      // GÜNCELLEME: Parametreyi burada gönderiyoruz.
                                      // Kenar paneli dikey bir alandır.
                                      palleteLayoutAxis: Axis.vertical,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  child: LayoutCanvas(),
                                ),
                              ],
                            );
                          } else {
                            // Dikey/Mobil Yerleşim
                            return Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  height: _isPanelVisible ? constraints.maxHeight * 0.35 : 0,
                                  child: const ClipRect(
                                    child: TablePalette(
                                      // GÜNCELLEME: Parametreyi burada gönderiyoruz.
                                      // Üst panel yatay bir alandır.
                                      palleteLayoutAxis: Axis.horizontal,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  child: LayoutCanvas(),
                                ),
                              ],
                            );
                          }
                        },
                      ),
          );
        },
      ),
    );
  }
}