// lib/widgets/table_layout/draggable_layout_element.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/layout_element.dart';
import '../../providers/table_layout_provider.dart';
import 'element_renderer.dart';
import 'element_editor.dart';

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
    final provider = context.read<TableLayoutProvider>();
    final isSelected = provider.selectedItem is LayoutElement && (provider.selectedItem as LayoutElement).id == element.id;

    return Positioned(
      left: element.position.dx,
      top: element.position.dy,
      child: Draggable<LayoutElement>(
        data: element,
        feedback: Material(
          color: Colors.transparent,
          child: ElementRenderer(element: element, isSelected: true),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: ElementRenderer(element: element, isSelected: isSelected),
        ),
        onDragStarted: () {
          provider.selectItem(element);
        },
        // GÜNCELLENDİ: Sürükleme bittiğinde artık sadece global ekran
        // pozisyonunu provider'a gönderiyoruz. Provider, bu pozisyonu
        // canvas'ın lokal koordinatına kendisi çevirecek.
        onDragEnd: (details) {
          provider.updateItemPositionAfterDrag(element, details.offset);
        },
        child: GestureDetector(
          onTap: () {
            provider.selectItem(element);
          },
          // GÜNCELLENDİ: ElementEditor'ı yeni haliyle çağırıyoruz.
          // Provider'ı doğrudan vermek yerine 'onSave' callback'i tanımlıyoruz.
          onDoubleTap: () async {
            await showDialog(
              context: context,
              useRootNavigator: false,
              builder: (dialogContext) => ElementEditor(
                element: element,
                onSave: (updatedElement) {
                  // ElementEditor'dan dönen güncel element bilgisini
                  // provider'daki metot ile state'e işliyoruz.
                  provider.updateElementProperties(
                    element,
                    size: updatedElement.size,
                    rotation: updatedElement.rotation,
                    styleUpdates: updatedElement.styleProperties,
                  );
                },
              ),
            );
          },
          child: ElementRenderer(element: element, isSelected: isSelected),
        ),
      ),
    );
  }
}