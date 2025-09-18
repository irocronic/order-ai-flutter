// lib/widgets/table_layout/draggable_table.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/table_model.dart';
import '../../providers/table_layout_provider.dart';

class DraggableTable extends StatelessWidget {
  final TableModel table;

  // HATA DÜZELTMESİ: 'constraints' parametresi kaldırıldı.
  const DraggableTable({
    Key? key,
    required this.table,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TableLayoutProvider>(context, listen: false);
    final isSelected = provider.selectedItem is TableModel && (provider.selectedItem as TableModel).id == table.id;

    final tableWidget = Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          provider.selectItem(table);
        },
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade200 : Colors.blue.shade50,
            border: Border.all(
              color: isSelected ? Colors.blue.shade700 : Colors.blue.shade200,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              // l10n hatasını gidermek için AppLocalizations.of(context) kullanıldı
              AppLocalizations.of(context)!.tableLayoutPaletteTableLabel(table.tableNumber.toString()),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.blue.shade900 : Colors.blue.shade700,
              ),
            ),
          ),
        ),
      ),
    );

    return Draggable<TableModel>(
      data: table,
      feedback: tableWidget,
      childWhenDragging: Container(),
      onDragUpdate: (details) {
        // Bu, sürükleme sırasında anlık pozisyon güncellemesi sağlar.
        // Ancak performansı etkileyebilir. Genellikle onDragEnd kullanılır.
      },
      onDragEnd: (details) {
        // DragTarget bu işlevi üstlendiği için burada ek bir logik gerekmiyor.
      },
      child: tableWidget,
    );
  }
}