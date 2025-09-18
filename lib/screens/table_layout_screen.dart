// lib/screens/table_layout_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_layout_provider.dart';
import '../widgets/table_layout/layout_canvas.dart';
import '../widgets/table_layout/table_palette.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TableLayoutScreen extends StatelessWidget {
  const TableLayoutScreen({Key? key}) : super(key: key);

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
                           SnackBar(content: Text(provider.errorMessage.isEmpty ? l10n.tableLayoutSuccessSave : l10n.tableLayoutErrorSave), backgroundColor: provider.errorMessage.isEmpty ? Colors.green : Colors.red),
                        );
                      }
                    },
                  ),
              ],
            ),
            body: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.errorMessage.isNotEmpty
                    ? Center(child: Text(provider.errorMessage))
                    : Row(
                        children: const [
                          TablePalette(),
                          Expanded(
                            child: LayoutCanvas(),
                          ),
                        ],
                      ),
          );
        },
      ),
    );
  }
}