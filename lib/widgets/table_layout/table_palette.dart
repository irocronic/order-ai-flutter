// lib/widgets/table_layout/table_palette.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../providers/table_layout_provider.dart';
import '../../models/layout_element.dart';
import '../../models/shape_style.dart';
import '../../models/table_model.dart';

class TablePalette extends StatelessWidget {
  final Axis palleteLayoutAxis;

  const TablePalette({
    Key? key,
    required this.palleteLayoutAxis,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TableLayoutProvider>();
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
              IconButton(
                icon: const Icon(Icons.text_fields),
                tooltip: l10n.tableLayoutPaletteAddText,
                onPressed: () {
                  provider.addElement(LayoutElementType.text, l10n.tableLayoutPaletteDefaultText, null);
                },
              ),
              IconButton(
                icon: const Icon(Icons.check_box_outline_blank),
                tooltip: l10n.tableLayoutPaletteAddRectangle,
                onPressed: () {
                  provider.addElement(LayoutElementType.shape, 'rectangle', ShapeType.rectangle);
                },
              ),
              IconButton(
                icon: const Icon(Icons.circle_outlined),
                tooltip: l10n.tableLayoutPaletteAddEllipse,
                onPressed: () {
                  provider.addElement(LayoutElementType.shape, 'ellipse', ShapeType.ellipse);
                },
              ),
              IconButton(
                icon: const Icon(Icons.linear_scale),
                tooltip: l10n.tableLayoutPaletteAddLine,
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
          const SizedBox(height: 8),
          Expanded(
            child: provider.unplacedTables.isEmpty
                ? Center(child: Text(l10n.tableLayoutPaletteAllTablesPlaced, textAlign: TextAlign.center))
                : buildTableList(context, provider),
          ),
        ],
      ),
    );
  }
  
  Widget buildTableList(BuildContext context, TableLayoutProvider provider) {
    // Geniş ekranda panelimiz dikey bir sütun gibi davranır. İçine Grid koyarız.
    if (palleteLayoutAxis == Axis.vertical) {
      return GridView.builder(
        padding: const EdgeInsets.only(top: 4.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: provider.unplacedTables.length,
        itemBuilder: (context, index) {
          final table = provider.unplacedTables[index];
          return _buildDraggableTableIcon(context, table, 65.0, 14.0);
        },
      );
    }
    // Dar ekranda panelimiz yatay bir satır gibi davranır. İçine yatay liste koyarız.
    else {
      return SizedBox(
        height: 65,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: provider.unplacedTables.length,
          itemBuilder: (context, index) {
            final table = provider.unplacedTables[index];
            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: _buildDraggableTableIcon(context, table, 55.0, 12.0),
            );
          },
        ),
      );
    }
  }

  Widget _buildDraggableTableIcon(BuildContext context, TableModel table, double iconSize, double fontSize) {
    final l10n = AppLocalizations.of(context)!;

    final tableWidget = Container(
      constraints: BoxConstraints(
        maxWidth: iconSize,
        maxHeight: iconSize * 1.5,
      ),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 3,
            offset: const Offset(1, 1),
          )
        ],
      ),
      child: Center(
        child: Text(
          l10n.tableLayoutPaletteTableLabel(table.tableNumber.toString()),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            color: Colors.blue.shade800,
          ),
        ),
      ),
    );

    // GÜNCELLEME: Draggable -> LongPressDraggable olarak değiştirildi.
    // Bu değişiklik, sürükleme işlemini sadece öğeye uzun basıldığında başlatır.
    // Böylece normal swipe hareketi listenin kaydırılmasını sağlar.
    return LongPressDraggable<Object>(
      data: table,
      feedback: Material(
        elevation: 4.0,
        color: Colors.transparent,
        child: SizedBox(
          width: iconSize,
          height: iconSize,
          child: tableWidget,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: tableWidget,
      ),
      child: tableWidget,
    );
  }
}