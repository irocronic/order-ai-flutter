// lib/widgets/table_layout/layout_canvas.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/table_layout_provider.dart';
import 'draggable_layout_element.dart';
import 'draggable_table.dart';
import 'grid_painter.dart';
import '../../models/table_model.dart';
import '../../models/layout_element.dart';

/// Yerleşim planı çizim alanı (canvas)
class LayoutCanvas extends StatefulWidget {
  const LayoutCanvas({Key? key}) : super(key: key);

  @override
  State<LayoutCanvas> createState() => _LayoutCanvasState();
}

class _LayoutCanvasState extends State<LayoutCanvas> {
  /// Canvas Stack’ini referans almak için GlobalKey
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // build sonrası provider’a key’i set et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TableLayoutProvider>().setCanvasKey(_canvasKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TableLayoutProvider>();
    final layout = provider.layout;

    if (layout == null) {
      return const Center(
        child: Text('Yerleşim planı yüklenemedi.'),
      );
    }

    const double canvasPadding = 50.0;

    return Container(
      color: Colors.blueGrey.shade100,
      child: InteractiveViewer(
        maxScale: 2.0,
        minScale: 0.5,
        boundaryMargin: const EdgeInsets.all(canvasPadding),
        constrained: false,
        child: DragTarget<Object>(
          onAcceptWithDetails: (details) {
            final renderBox =
                _canvasKey.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox == null) return;

            final localOffset = renderBox.globalToLocal(details.offset);

            if (details.data is TableModel) {
              provider.placeTableOnCanvas(
                details.data as TableModel,
                localOffset,
              );
            } else if (details.data is LayoutElement) {
              provider.updateDroppedElementPosition(
                details.data as LayoutElement,
                localOffset,
              );
            }
          },
          builder: (context, candidateData, rejectedData) {
            return SizedBox(
              width: layout.width + (canvasPadding * 2),
              height: layout.height + (canvasPadding * 2),
              child: Stack(
                children: [
                  Positioned(
                    left: canvasPadding,
                    top: canvasPadding,
                    child: Container(
                      width: layout.width,
                      height: layout.height,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade400),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Stack(
                        key: _canvasKey,
                        clipBehavior: Clip.none,
                        children: [
                          if (provider.isGridVisible)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: GridPainter(
                                  gridSpacing: provider.gridSpacing,
                                  gridColor: Colors.grey.shade300,
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: provider.deselectAll,
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                          // Yerleştirilmiş masalar
                          ...provider.placedTables.map(
                            (table) => DraggableTable(table: table),
                          ),
                          // Diğer öğeler (metin, şekil vb.)
                          ...provider.elements.map(
                            (element) => DraggableLayoutElement(
                              element: element,
                              constraints: BoxConstraints.expand(
                                width: layout.width,
                                height: layout.height,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
