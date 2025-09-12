// lib/widgets/setup_wizard/menu_items/services/template_selection_service.dart
import '../../../../services/api_service.dart';

class TemplateSelectionService {
  final String token;

  TemplateSelectionService(this.token);

  Future<List<dynamic>> fetchTemplatesForCategory(String categoryName) async {
    return await ApiService.fetchMenuItemTemplates(
      token,
      categoryTemplateName: categoryName,
    );
  }

  Future<List<dynamic>> fetchVariantTemplatesForCategory(String categoryName) async {
    return await ApiService.fetchVariantTemplates(
      token,
      categoryTemplateName: categoryName,
    );
  }

  Future<List<dynamic>> fetchDefaultVariantTemplates() async {
    return await ApiService.fetchVariantTemplates(token);
  }
}