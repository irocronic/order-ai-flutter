// lib/widgets/table_layout/layout_canvas.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/table_model.dart';
import '../../models/layout_element.dart';
import '../../providers/table_layout_provider.dart';
import 'draggable_table.dart';
import 'draggable_layout_element.dart';

class LayoutCanvas extends StatefulWidget {
  const LayoutCanvas({Key? key}) : super(key: key);

  @override
  _LayoutCanvasState createState() => _LayoutCanvasState();
}

class _LayoutCanvasState extends State<LayoutCanvas> {
  final TransformationController _transformationController = TransformationController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TableLayoutProvider>(context);
    final layout = provider.layout;

    if (layout == null) {
      return const Center(child: Text("Yerleşim planı yüklenemedi."));
    }

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.1,
        maxScale: 4.0,
        constrained: false,
        child: DragTarget<Object>(
          onAcceptWithDetails: (details) {
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final Offset localOffset = renderBox.globalToLocal(details.offset);
            final Matrix4 matrix = _transformationController.value.clone()..invert();
            final Offset transformedOffset = MatrixUtils.transformPoint(matrix, localOffset);

            // HATA DÜZELTMESİ (Sürükle-Bırak): Hem TableModel hem de LayoutElement için pozisyon güncelleme mantığı eklendi.
            if (details.data is TableModel) {
              provider.placeTableOnCanvas(details.data as TableModel, transformedOffset);
            } else if (details.data is LayoutElement) {
              provider.updateDroppedElementPosition(details.data as LayoutElement, transformedOffset);
            }
          },
          builder: (context, candidateData, rejectedData) {
            return SizedBox(
              width: layout.width,
              height: layout.height,
              child: Stack(
                children: [
                  ...provider.placedTables.map((table) {
                    return Positioned(
                      left: table.posX ?? 0,
                      top: table.posY ?? 0,
                      child: DraggableTable(
                        table: table,
                      ),
                    );
                  }).toList(),
                  ...provider.elements.map((element) {
                    return Positioned(
                      left: element.position.dx,
                      top: element.position.dy,
                      child: DraggableLayoutElement(
                        element: element,
                        constraints: BoxConstraints(
                          maxWidth: layout.width,
                          maxHeight: layout.height,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}