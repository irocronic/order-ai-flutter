// lib/widgets/table_layout/draggable_table.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/table_model.dart';
import '../../providers/table_layout_provider.dart';
import 'table_widget.dart';
// YENİ IMPORT
import '../../models/i_layout_item.dart';

class DraggableTable extends StatelessWidget {
  final TableModel table;

  const DraggableTable({
    Key? key,
    required this.table,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TableLayoutProvider>();
    // GÜNCELLENDİ: Tip kontrolü `ILayoutItem` üzerinden yapılıyor.
    final isSelected = provider.selectedItem is TableModel && (provider.selectedItem as TableModel).id == table.id;

    return Positioned(
      left: table.posX,
      top: table.posY,
      child: Draggable<TableModel>(
        data: table,
        feedback: Material(
          color: Colors.transparent,
          child: TableWidget(table: table, isSelected: true),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: TableWidget(table: table, isSelected: isSelected),
        ),
        onDragStarted: () {
          provider.selectItem(table);
        },
        // GÜNCELLENDİ: Sürükleme bittiğinde artık sadece global ekran
        // pozisyonunu provider'a gönderiyoruz. Provider, bu pozisyonu
        // canvas'ın lokal koordinatına kendisi çevirecek.
        onDragEnd: (details) {
          provider.updateItemPositionAfterDrag(table, details.offset);
        },
        child: GestureDetector(
          onTap: () {
            provider.selectItem(table);
          },
          child: TableWidget(table: table, isSelected: isSelected),
        ),
      ),
    );
  }
}