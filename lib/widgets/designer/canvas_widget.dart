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
      // Sabit bir çizgi kalınlığı belirliyoruz. InteractiveViewer yakınlaştırma yaptığında
      // bu çizgi de görsel olarak kalınlaşacaktır, bu beklenen bir davranıştır.
      // Çizginin her zaman 1 piksel kalmasını sağlamak daha karmaşık bir mantık gerektirir.
      ..strokeWidth = 1.0;
    for (var guide in guides) {
      if (guide.axis == Axis.vertical) {
        canvas.drawLine(
          Offset(guide.position, 0),
          Offset(guide.position, size.height),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(0, guide.position),
          Offset(size.width, guide.position),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GuidePainter oldDelegate) {
    // Sadece kılavuz listesi değişirse yeniden çiz
    return oldDelegate.guides != guides || oldDelegate.scale != scale;
  }
}

class CanvasWidget extends StatelessWidget {
  const CanvasWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessCardProvider>();
    final cardModel = provider.cardModel;

    // Arka plan dekorasyonu
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

    // CanvasWidget artık her zaman tam boyutunda çizim yapan sabit boyutlu bir widget.
    // Ekrana sığdırma ve ölçeklendirme görevini tamamen ebeveynindeki InteractiveViewer üstleniyor.
    return SizedBox(
      width: cardModel.dimensions.width,
      height: cardModel.dimensions.height,
      child: Container(
        decoration: decoration,
        child: Stack(
          // clipBehavior, elemanların etrafındaki tutamaçların ve seçim çerçevesinin
          // tuvalin dışına taşabilmesi için gereklidir.
          clipBehavior: Clip.none,
          children: [
            // Boş alana tıklayınca seçim temizle
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  context.read<BusinessCardProvider>().selectElement(null);
                },
                child: Container(color: Colors.transparent),
              ),
            ),

            // Kart elemanları, artık doğru ve sabit boyutlu bir koordinat sistemi içinde konumlandırılıyor.
            ...cardModel.elements.map((element) {
              return TransformableElementWidget(
                element: element,
                isSelected:
                    provider.selectedElementIds.contains(element.id),
              );
            }).toList(),

            // Hizalama kılavuzları (dokunmayı engelle)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: GuidePainter(
                    provider.activeGuides,
                    1.0, // Şimdilik varsayılan ölçek 1.0 olarak ayarlandı.
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

