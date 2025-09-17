// lib/widgets/designer/canvas_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/business_card_model.dart';
import '../../providers/business_card_provider.dart';
import 'transformable_element_widget.dart';

class GuidePainter extends CustomPainter {
  final List<AlignmentGuide> guides;
  final double scale;

  GuidePainter(this.guides, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.0 / scale;
    for (var guide in guides) {
      if (guide.axis == Axis.vertical) {
        canvas.drawLine(Offset(guide.position, 0),
            Offset(guide.position, size.height), paint);
      } else {
        canvas.drawLine(
            Offset(0, guide.position), Offset(size.width, guide.position), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CanvasWidget extends StatelessWidget {
  const CanvasWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessCardProvider>();
    final cardModel = provider.cardModel;

    BoxDecoration decoration;
    if (cardModel.gradientEndColor != null && cardModel.gradientType != null) {
      decoration = BoxDecoration(
        gradient: cardModel.gradientType == GradientType.linear
            ? LinearGradient(
                colors: [
                  cardModel.gradientStartColor,
                  cardModel.gradientEndColor!
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : RadialGradient(
                colors: [
                  cardModel.gradientStartColor,
                  cardModel.gradientEndColor!
                ],
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      );
    } else {
      decoration = BoxDecoration(
        color: cardModel.gradientStartColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      );
    }

    return Center(
      child: InteractiveViewer(
        maxScale: 5.0,
        minScale: 0.5,
        boundaryMargin: const EdgeInsets.all(50),
        panEnabled: provider.isCanvasPanningEnabled,
        scaleEnabled: provider.isCanvasPanningEnabled,
        child: AspectRatio(
          aspectRatio: cardModel.dimensions.width / cardModel.dimensions.height,
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: decoration,
            clipBehavior: Clip.none,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      context.read<BusinessCardProvider>().selectElement(null);
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
                ...cardModel.elements.map((element) {
                  return TransformableElementWidget(
                    element: element,
                    isSelected:
                        provider.selectedElementIds.contains(element.id),
                  );
                }).toList(),
                
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: GuidePainter(
                        provider.activeGuides,
                        1.0, 
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}