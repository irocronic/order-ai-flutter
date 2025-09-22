// lib/widgets/designer/transformable_element_widget.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/business_card_model.dart';
import '../../providers/business_card_provider.dart';
import 'element_widget.dart';

class TransformableElementWidget extends StatefulWidget {
  final CardElement element;
  final bool isSelected;

  const TransformableElementWidget({
    Key? key,
    required this.element,
    required this.isSelected,
  }) : super(key: key);

  @override
  State<TransformableElementWidget> createState() =>
      _TransformableElementWidgetState();
}

class _TransformableElementWidgetState extends State<TransformableElementWidget> {
  late BusinessCardModel _previewModel;
  late BusinessCardModel _initialModel;
  late DragStartDetails _dragStartDetails;
  late double _initialRotation;
  Offset? _centerGlobal;

  @override
  Widget build(BuildContext context) {
    // LOG: Bu widget'ın hangi veriyle oluşturulduğunu görelim.
    // print('--- Building TransformableElement ID: ${widget.element.id} at ${widget.element.position} with size ${widget.element.size}');

    final provider = context.read<BusinessCardProvider>();

    Widget buildHandle(Alignment alignment) {
      return Align(
        alignment: alignment,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpLeftDownRight,
          child: GestureDetector(
            onPanStart: (details) {
              _initialModel = provider.cardModel;
            },
            onPanUpdate: (details) {
              final newElements = provider.cardModel.elements.map((e) {
                if (provider.selectedElementIds.contains(e.id)) {
                  return e.copyWith(
                      size: Size(
                    max(20, e.size.width + details.delta.dx),
                    max(20, e.size.height + details.delta.dy),
                  ));
                }
                return e;
              }).toList();
              _previewModel = provider.cardModel.copyWith(elements: newElements);
              provider.updateModelForPreview(_previewModel);
            },
            onPanEnd: (details) {
              provider.updateModel(_initialModel, _previewModel);
            },
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 1.5),
              ),
            ),
          ),
        ),
      );
    }

    Widget buildRotationHandle() {
      return Align(
        alignment: Alignment.topCenter,
        child: Transform.translate(
          offset: const Offset(0, -20),
          child: MouseRegion(
            cursor: SystemMouseCursors.grabbing,
            child: GestureDetector(
              onPanStart: (details) {
                _initialModel = provider.cardModel;
                _dragStartDetails = details;
                _initialRotation = widget.element.rotation;

                // Burada element merkezinin global koordinatını hesaplıyoruz.
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  // TransformableElementWidget Positioned olduğu için,
                  // renderBox'ın lokal (0,0) noktası elementin sol üst köşesiyle eşleşir.
                  _centerGlobal = renderBox.localToGlobal(widget.element.size.center(Offset.zero));
                } else {
                  _centerGlobal = null;
                }
              },
              onPanUpdate: (details) {
                if (_centerGlobal == null) return;

                final startVector = _dragStartDetails.globalPosition - _centerGlobal!;
                final currentVector = details.globalPosition - _centerGlobal!;
                final angleDelta =
                    currentVector.direction - startVector.direction;
                final newElements = provider.cardModel.elements.map((e) {
                  if (provider.selectedElementIds.contains(e.id)) {
                    return e.copyWith(rotation: _initialRotation + angleDelta);
                  }
                  return e;
                }).toList();
                _previewModel =
                    provider.cardModel.copyWith(elements: newElements);
                provider.updateModelForPreview(_previewModel);
              },
              onPanEnd: (details) {
                provider.updateModel(_initialModel, _previewModel);
              },
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black54),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return Positioned(
      left: widget.element.position.dx,
      top: widget.element.position.dy,
      child: Listener(
        onPointerDown: (_) {
          // print('>>> LISTENER onPointerDown -- Element ID: ${widget.element.id}');
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // print('>>> GESTUREDETECTOR onTap -- Element ID: ${widget.element.id} -- Selecting element...');
            provider.selectElement(
              widget.element.id,
              addToSelection: provider.isShiftPressed,
            );
          },
          onPanStart: (_) {
            _initialModel = provider.cardModel;
            if (!provider.selectedElementIds.contains(widget.element.id)) {
              provider.selectElement(
                widget.element.id,
                addToSelection: provider.isShiftPressed,
              );
            }
          },
          onPanUpdate: (details) {
            final newElements = provider.cardModel.elements.map((e) {
              if (provider.selectedElementIds.contains(e.id)) {
                return e.copyWith(position: e.position + details.delta);
              }
              return e;
            }).toList();

            _previewModel = provider.cardModel.copyWith(elements: newElements);
            provider.updateModelForPreview(_previewModel);

            final draggedElement = _previewModel.elements
                .firstWhere((e) => e.id == widget.element.id);
            final draggedRect = Rect.fromLTWH(
                draggedElement.position.dx,
                draggedElement.position.dy,
                draggedElement.size.width,
                draggedElement.size.height);
            provider.updateAlignmentGuides(draggedRect);
          },
          onPanEnd: (_) {
            provider.updateModel(_initialModel, _previewModel);
            provider.clearAlignmentGuides();
          },
          child: SizedBox(
            width: widget.element.size.width,
            height: widget.element.size.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ElementWidget(
                  element: widget.element,
                  isSelected: widget.isSelected,
                ),
                if (widget.isSelected) ...[
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 1.5),
                      ),
                    ),
                  ),
                  buildHandle(Alignment.bottomRight),
                  buildRotationHandle(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}