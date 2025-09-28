// lib/widgets/designer/template_gallery_dialog.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/template_model.dart';
import '../../providers/business_card_provider.dart';

class TemplateGalleryDialog extends StatefulWidget {
  const TemplateGalleryDialog({Key? key}) : super(key: key);

  @override
  State<TemplateGalleryDialog> createState() => _TemplateGalleryDialogState();
}

class _TemplateGalleryDialogState extends State<TemplateGalleryDialog> {
  // Örnek şablon listesi. Bunu dışarıdan da alabilirsiniz.
  final List<Template> _templates = [
    Template(
      name: "Business Card V1",
      assetPath: 'assets/templates/modern_template.json',
      previewImagePath: 'assets/previews/modern.png', 
    ),
    Template(
      name: "Business Card V2",
      assetPath: 'assets/templates/classic_template.json',
      previewImagePath: 'assets/previews/classic.png', 
    ),
    Template(
      name: "Logo V1",
      assetPath: 'assets/templates/logo.json',
      previewImagePath: 'assets/previews/logo.png',
    ),
  ];

  Future<void> _loadTemplate(BuildContext context, String assetPath) async {
    final l10n = AppLocalizations.of(context)!;
    
    try {
      final String jsonString = await rootBundle.loadString(assetPath);
      final provider = context.read<BusinessCardProvider>();
      provider.loadCardFromJson(jsonString);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.templateLoadedSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.templateLoadError(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(l10n.templateGalleryTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: _templates.length,
          itemBuilder: (context, index) {
            final template = _templates[index];
            return GestureDetector(
              onTap: () => _loadTemplate(context, template.assetPath),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade200,
                        child: Image.asset(
                          template.previewImagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(child: Icon(Icons.image_not_supported));
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(template.name, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
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