// YENİ DOSYA: lib/models/template_model.dart

class Template {
  final String name;
  final String assetPath; // Varlıkların yolunu tutar
  final String previewImagePath; // Önizleme görselinin yolu

  Template({
    required this.name,
    required this.assetPath,
    required this.previewImagePath,
  });
}