// lib/services/pdf_export_service.dart

// lib/services/pdf_export_service.dart

import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart'; // GÜNCELLEME: Font yüklemek için eklendi.
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/business_card_model.dart';
import '../models/card_icon_enum.dart';
import '../models/shape_style.dart';

class PdfExportService {
  static Future<void> generateAndShareCard(
      material.BuildContext context, BusinessCardModel cardModel) async {
    final pdf = pw.Document();

    final fontMap = await _loadFonts(cardModel);
    final iconFont = await PdfGoogleFonts.materialIcons();

    // GÜNCELLEME: FontAwesome fontunu asset'lerden yüklüyoruz.
    // Bu kodun çalışması için TTF dosyasını projenize ekleyip pubspec.yaml'da
    // asset olarak tanımladığınızdan emin olun.
    final fontAwesomeTtf =
        await rootBundle.load("assets/fonts/fa-solid-900.ttf");
    final fontAwesome = pw.TtfFont(fontAwesomeTtf);

    pdf.addPage(
      pw.Page(
        pageFormat:
            const PdfPageFormat(85 * PdfPageFormat.mm, 55 * PdfPageFormat.mm),
        build: (pw.Context context) {
          final scaleX = (85 * PdfPageFormat.mm) / cardModel.dimensions.width;
          final scaleY = (55 * PdfPageFormat.mm) / cardModel.dimensions.height;

          pw.BoxDecoration decoration;
          if (cardModel.gradientEndColor != null) {
            decoration = pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [
                  PdfColor.fromInt(cardModel.gradientStartColor.value),
                  PdfColor.fromInt(cardModel.gradientEndColor!.value)
                ],
              ),
            );
          } else {
            decoration = pw.BoxDecoration(
              color: PdfColor.fromInt(cardModel.gradientStartColor.value),
            );
          }

          return pw.Container(
            decoration: decoration,
            child: pw.Stack(
              children: cardModel.elements.map<pw.Widget>((element) {
                final scaledWidth = element.size.width * scaleX;
                final scaledHeight = element.size.height * scaleY;

                final pdfX = element.position.dx * scaleX;
                final pdfY = (cardModel.dimensions.height -
                        element.position.dy -
                        element.size.height) *
                    scaleY;

                return pw.Positioned(
                  left: pdfX,
                  bottom: pdfY,
                  child: pw.Opacity(
                    opacity: element.opacity,
                    child: pw.SizedBox(
                      width: scaledWidth,
                      height: scaledHeight,
                      child: pw.Transform.rotate(
                        angle: -element.rotation,
                        child: _buildPdfElement(
                          element,
                          fontMap,
                          iconFont,
                          fontAwesome, // GÜNCELLEME: Yüklenen fontu metoda gönder.
                          scaleX,
                          scaleY,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static Future<pw.Font> _getFontForFamily(String family,
      material.FontWeight? weight, material.FontStyle? style) async {
    bool isBold = weight == material.FontWeight.bold;
    bool isItalic = style == material.FontStyle.italic;

    try {
      switch (family) {
        case 'Lato':
          if (isBold && isItalic) return await PdfGoogleFonts.latoBoldItalic();
          if (isBold) return await PdfGoogleFonts.latoBold();
          if (isItalic) return await PdfGoogleFonts.latoItalic();
          return await PdfGoogleFonts.latoRegular();
        case 'Montserrat':
          if (isBold && isItalic)
            return await PdfGoogleFonts.montserratBoldItalic();
          if (isBold) return await PdfGoogleFonts.montserratBold();
          if (isItalic) return await PdfGoogleFonts.montserratItalic();
          return await PdfGoogleFonts.montserratRegular();
        case 'Oswald':
          if (isBold) return await PdfGoogleFonts.oswaldBold();
          return await PdfGoogleFonts.oswaldRegular();
        case 'Merriweather':
          if (isBold && isItalic)
            return await PdfGoogleFonts.merriweatherBoldItalic();
          if (isBold) return await PdfGoogleFonts.merriweatherBold();
          if (isItalic) return await PdfGoogleFonts.merriweatherItalic();
          return await PdfGoogleFonts.merriweatherRegular();
        case 'Roboto':
        default:
          if (isBold && isItalic)
            return await PdfGoogleFonts.robotoBoldItalic();
          if (isBold) return await PdfGoogleFonts.robotoBold();
          if (isItalic) return await PdfGoogleFonts.robotoItalic();
          return await PdfGoogleFonts.robotoRegular();
      }
    } catch (e) {
      return await PdfGoogleFonts.robotoRegular();
    }
  }

  static Future<Map<String, pw.Font>> _loadFonts(
      BusinessCardModel cardModel) async {
    final Map<String, pw.Font> fontMap = {};
    for (var element in cardModel.elements) {
      if (element.type == CardElementType.text) {
        final style = element.style;
        final fontFamily = style.fontFamily ?? 'Roboto';
        final fontWeight = style.fontWeight;
        final fontStyle = style.fontStyle;
        final fontKey = "${fontFamily}_${fontWeight}_${fontStyle}";

        if (!fontMap.containsKey(fontKey)) {
          fontMap[fontKey] =
              await _getFontForFamily(fontFamily, fontWeight, fontStyle);
        }
      }
    }
    return fontMap;
  }

  static pw.Widget _buildPdfElement(
    CardElement element,
    Map<String, pw.Font> fontMap,
    pw.Font iconFont,
    pw.Font fontAwesome, // GÜNCELLEME: Yeni parametre eklendi.
    double scaleX,
    double scaleY,
  ) {
    pw.Font getFont(material.TextStyle style) {
      final family = style.fontFamily ?? 'Roboto';
      final key = "${family}_${style.fontWeight}_${style.fontStyle}";
      return fontMap[key]!;
    }

    switch (element.type) {
      case CardElementType.text:
        return pw.Text(
          element.content,
          textAlign: pw.TextAlign.values[element.textAlign.index],
          style: pw.TextStyle(
            font: getFont(element.style),
            fontSize: element.style.fontSize! * scaleY * 0.95,
            color: PdfColor.fromInt(element.style.color!.value),
            letterSpacing: element.style.letterSpacing,
            height: element.style.height,
          ),
        );
      case CardElementType.icon:
        material.IconData iconData;
        try {
          final icon = CardIcon.values.byName(element.content);
          switch (icon) {
            case CardIcon.phone:
              iconData = material.Icons.phone;
              break;
            case CardIcon.email:
              iconData = material.Icons.email;
              break;
            case CardIcon.web:
              iconData = material.Icons.language;
              break;
            case CardIcon.location:
              iconData = material.Icons.location_on;
              break;
            case CardIcon.linkedin:
              iconData = material.Icons.contact_mail;
              break;
            case CardIcon.twitter:
              iconData = material.Icons.flutter_dash;
              break;
            case CardIcon.github:
              iconData = material.Icons.code;
              break;
          }
        } catch (e) {
          iconData = material.Icons.circle;
        }
        return pw.Text(
          String.fromCharCode(iconData.codePoint),
          style: pw.TextStyle(
              font: iconFont,
              fontSize: element.size.height * scaleY,
              color: PdfColor.fromInt(element.style.color!.value)),
        );
      case CardElementType.image:
        if (element.imageData != null) {
          final image = pw.MemoryImage(element.imageData!);
          return pw.Image(image, fit: pw.BoxFit.cover);
        }
        return pw.Center(child: pw.Text("Görsel Alanı"));
      case CardElementType.qrCode:
        return pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: element.content,
          color: PdfColor.fromInt(
              element.style.color?.value ?? material.Colors.black.value),
        );
      case CardElementType.group:
        return pw.SizedBox(); // Gruplar PDF'te görünmez

      case CardElementType.shape:
        if (element.shapeStyle != null) {
          final style = element.shapeStyle!;
          switch (style.shapeType) {
            case ShapeType.rectangle:
              return pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(style.fillColor.value),
                  border: pw.Border.all(
                    color: PdfColor.fromInt(style.borderColor.value),
                    width: style.borderWidth * scaleY,
                  ),
                ),
              );
            case ShapeType.ellipse:
              return pw.ClipOval(
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(style.fillColor.value),
                    border: pw.Border.all(
                      color: PdfColor.fromInt(style.borderColor.value),
                      width: style.borderWidth * scaleY,
                    ),
                  ),
                ),
              );
            case ShapeType.line:
              return pw.Container(
                height: style.borderWidth * scaleY,
                color: PdfColor.fromInt(style.borderColor.value),
              );
          }
        }
        return pw.SizedBox();
        
      case CardElementType.svg:
        return pw.SvgImage(svg: element.content);

      // GÜNCELLEME: Eksik olan case durumu eklendi.
      case CardElementType.fontAwesomeIcon:
        final codePoint = int.tryParse(element.content) ?? 0;
        return pw.Text(
          String.fromCharCode(codePoint),
          style: pw.TextStyle(
            font: fontAwesome,
            fontSize: element.size.width * scaleX,
            color: PdfColor.fromInt(element.style.color!.value),
          ),
        );
    }
  }
}