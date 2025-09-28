// lib/widgets/designer/icon_gallery_dialog.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(l10n.iconGallery),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _icons.length,
          itemBuilder: (context, index) {
            final icon = _icons[index];
            return InkWell(
              onTap: () {
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
          child: Text(l10n.close),
        ),
      ],
    );
  }
}