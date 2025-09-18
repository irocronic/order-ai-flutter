// lib/widgets/table_layout/table_palette.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../providers/table_layout_provider.dart';
import '../../models/layout_element.dart';
import '../../models/shape_style.dart';

class TablePalette extends StatelessWidget {
  const TablePalette({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TableLayoutProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dekoratif Eleman Ekleme Bölümü
          Text(
            l10n.tableLayoutPaletteAddElements,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: [
              // DEĞİŞİKLİK 1: Metin Ekle butonu IconButton olarak güncellendi.
              IconButton(
                icon: const Icon(Icons.text_fields),
                tooltip: l10n.tableLayoutPaletteAddText, // Metin, tooltip olarak eklendi.
                onPressed: () {
                  provider.addElement(LayoutElementType.text, l10n.tableLayoutPaletteDefaultText, null);
                },
              ),
              // DEĞİŞİKLİK 2: Dikdörtgen Ekle butonu IconButton olarak güncellendi.
              IconButton(
                icon: const Icon(Icons.check_box_outline_blank),
                tooltip: l10n.tableLayoutPaletteAddRectangle, // Metin, tooltip olarak eklendi.
                onPressed: () {
                  provider.addElement(LayoutElementType.shape, 'rectangle', ShapeType.rectangle);
                },
              ),
              // DEĞİŞİKLİK 3: Elips Ekle butonu IconButton olarak güncellendi.
              IconButton(
                icon: const Icon(Icons.circle_outlined),
                tooltip: l10n.tableLayoutPaletteAddEllipse, // Metin, tooltip olarak eklendi.
                onPressed: () {
                  provider.addElement(LayoutElementType.shape, 'ellipse', ShapeType.ellipse);
                },
              ),
              // DEĞİŞİKLİK 4: Çizgi Ekle butonu IconButton olarak güncellendi.
              IconButton(
                icon: const Icon(Icons.linear_scale),
                tooltip: l10n.tableLayoutPaletteAddLine, // Metin, tooltip olarak eklendi.
                onPressed: () {
                  provider.addElement(LayoutElementType.shape, 'line', ShapeType.line);
                },
              ),
            ],
          ),
          const Divider(height: 24),
          // Yerleştirilmemiş Masalar Bölümü
          Text(
            l10n.tableLayoutPaletteUnplacedTables(provider.unplacedTables.length),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: provider.unplacedTables.isEmpty
                ? Center(child: Text(l10n.tableLayoutPaletteAllTablesPlaced, textAlign: TextAlign.center))
                : GridView.builder(
                    padding: const EdgeInsets.only(top: 12.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: provider.unplacedTables.length,
                    itemBuilder: (context, index) {
                      final table = provider.unplacedTables[index];
                      final tableWidget = Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(l10n.tableLayoutPaletteTableLabel(table.tableNumber.toString()), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );

                      return Draggable<Object>(
                        data: table,
                        feedback: Material(
                          elevation: 4.0,
                          // Sürüklenirken görünecek widget'ın boyutunu sabitliyoruz.
                          child: SizedBox(
                            width: 80,
                            height: 60,
                            child: tableWidget,
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.4,
                          child: tableWidget,
                        ),
                        child: tableWidget,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}