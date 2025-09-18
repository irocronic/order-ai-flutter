// lib/widgets/table_layout/draggable_layout_element.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/layout_element.dart';
import '../../providers/table_layout_provider.dart';
import 'element_renderer.dart'; // Bu da elemanları çizecek widget
import 'element_editor.dart'; // Düzenleyici modal'ı açmak için

class DraggableLayoutElement extends StatelessWidget {
  final LayoutElement element;
  final BoxConstraints constraints;

  const DraggableLayoutElement({
    Key? key,
    required this.element,
    required this.constraints,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TableLayoutProvider>(context, listen: false);
    final isSelected = provider.selectedItem == element;

    return Draggable<LayoutElement>(
      data: element,
      feedback: Material(
        color: Colors.transparent,
        child: ElementRenderer(element: element, isSelected: false),
      ),
      childWhenDragging: Container(),
      onDragStarted: () {
        provider.selectItem(element);
      },
      onDragEnd: (details) {
        // DragTarget canvas tarafından yönetiliyor.
      },
      child: GestureDetector(
        onTap: () {
          provider.selectItem(element);
        },
        onDoubleTap: () async {
          // Burada mevcut provider'ı doğrudan ElementEditor'a geçiriyoruz.
          await showDialog(
            context: context,
            useRootNavigator: false,
            builder: (dialogContext) => ElementEditor(
              element: element,
              provider: provider, // <-- provider'ı geçiriyoruz
            ),
          );
        },
        onLongPress: () async {
          await showDialog(
            context: context,
            useRootNavigator: false,
            builder: (dialogContext) => ElementEditor(
              element: element,
              provider: provider,
            ),
          );
        },
        child: ElementRenderer(element: element, isSelected: isSelected),
      ),
    );
  }
}