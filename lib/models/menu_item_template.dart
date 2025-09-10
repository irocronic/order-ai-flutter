// lib/models/menu_item_template.dart

class MenuItemTemplate {
  final int id;
  final String name;
  final int categoryTemplateId;

  MenuItemTemplate({
    required this.id,
    required this.name,
    required this.categoryTemplateId,
  });

  factory MenuItemTemplate.fromJson(Map<String, dynamic> json) {
    return MenuItemTemplate(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Bilinmeyen Şablon',
      categoryTemplateId: json['category_template'] ?? 0,
    );
  }
}