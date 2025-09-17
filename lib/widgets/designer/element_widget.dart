// lib/widgets/designer/element_widget.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/business_card_model.dart';
import '../../models/card_icon_enum.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ElementWidget extends StatelessWidget {
  final CardElement element;
  final bool isSelected;

  const ElementWidget({
    Key? key,
    required this.element,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget child;

    switch (element.type) {
      case CardElementType.text:
        child = Text(
          element.content,
          textAlign: element.textAlign,
          style: GoogleFonts.getFont(
            element.style.fontFamily ?? 'Roboto',
            fontSize: element.style.fontSize,
            fontWeight: element.style.fontWeight,
            fontStyle: element.style.fontStyle,
            color: element.style.color,
            letterSpacing: element.style.letterSpacing,
            height: element.style.height,
            shadows: element.style.shadows,
          ),
        );
        break;
      case CardElementType.icon:
        IconData iconData;
        try {
          final icon = CardIcon.values.byName(element.content);
          switch (icon) {
            case CardIcon.phone: iconData = Icons.phone; break;
            case CardIcon.email: iconData = Icons.email; break;
            case CardIcon.web: iconData = Icons.language; break;
            case CardIcon.location: iconData = Icons.location_on; break;
            case CardIcon.linkedin: iconData = Icons.contact_mail; break;
            case CardIcon.twitter: iconData = Icons.flutter_dash; break;
            case CardIcon.github: iconData = Icons.code; break;
          }
        } catch (e) {
          iconData = Icons.circle;
        }
        child = Icon(iconData, size: element.size.height, color: element.style.color);
        break;
      case CardElementType.image:
        if (element.imageData != null) {
          child = Image.memory(
            element.imageData!,
            fit: BoxFit.cover,
          );
        } else {
          child = Container(
            color: Colors.grey.shade200,
            child: Icon(Icons.image_outlined,
                size: element.size.height / 2, color: Colors.grey),
          );
        }
        break;
      case CardElementType.qrCode:
        child = QrImageView(
          data: element.content,
          version: QrVersions.auto,
          size: element.size.width,
          backgroundColor: Colors.transparent,
        );
        break;
      case CardElementType.group:
        // DÜZELTME: BorderStyle.dashed standart bir enum üyesi değil.
        // Hata vermemesi için düz bir çerçeve ile değiştirildi.
        child = Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.5)),
          ),
        );
        break;
    }

    return Transform.rotate(
      angle: element.rotation,
      child: Opacity(
        opacity: element.opacity,
        child: SizedBox(
          width: element.size.width,
          height: element.size.height,
          child: child,
        ),
      ),
    );
  }
}