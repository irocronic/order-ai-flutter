// lib/widgets/designer/icon_gallery_dialog.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/business_card_provider.dart';

class IconGalleryDialog extends StatelessWidget {
  const IconGalleryDialog({Key? key}) : super(key: key);

  // Galeride göstermek istediğimiz ikonların listesi
  static final List<IconData> _icons = [
    // Sosyal Medya
    FontAwesomeIcons.facebook, FontAwesomeIcons.instagram, FontAwesomeIcons.twitter,
    FontAwesomeIcons.linkedin, FontAwesomeIcons.youtube, FontAwesomeIcons.whatsapp,
    FontAwesomeIcons.github, FontAwesomeIcons.tiktok,
    // İş ve İletişim
    FontAwesomeIcons.solidAddressBook, FontAwesomeIcons.solidBuilding, FontAwesomeIcons.briefcase,
    FontAwesomeIcons.globe, FontAwesomeIcons.phone, FontAwesomeIcons.at,
    // Diğer Semboller
    FontAwesomeIcons.star, FontAwesomeIcons.heart, FontAwesomeIcons.locationDot,
    FontAwesomeIcons.music, FontAwesomeIcons.camera, FontAwesomeIcons.code,
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("İkon Galerisi"),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, // Bir satırdaki ikon sayısı
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _icons.length,
          itemBuilder: (context, index) {
            final icon = _icons[index];
            return InkWell(
              onTap: () {
                // Seçilen ikonu provider aracılığıyla tuvale ekle
                context.read<BusinessCardProvider>().addFontAwesomeIconElement(icon);
                Navigator.of(context).pop();
              },
              child: FaIcon(icon, size: 28),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Kapat"),
        ),
      ],
    );
  }
}