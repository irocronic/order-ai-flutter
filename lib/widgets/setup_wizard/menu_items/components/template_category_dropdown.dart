// lib/widgets/setup_wizard/menu_items/components/template_category_dropdown.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TemplateCategoryDropdown extends StatelessWidget {
  final List<dynamic> availableCategories;
  final String? selectedCategoryName;
  final Function(String?) onCategoryChanged;

  const TemplateCategoryDropdown({
    Key? key,
    required this.availableCategories,
    required this.selectedCategoryName,
    required this.onCategoryChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DropdownButtonFormField<String>(
      value: selectedCategoryName,
      isExpanded: true,
      dropdownColor: const Color(0xFF1976D2), // ✅ Mavi ton dropdown arka planı
      iconEnabledColor: Colors.white,
      decoration: InputDecoration(
        labelText: l10n.templateCategoryDropdownLabel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
        labelStyle: const TextStyle(color: Colors.white), // ✅ Beyaz label
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)), // ✅ Beyaz hint
        filled: true,
        fillColor: Colors.white.withOpacity(0.1), // ✅ Hafif beyaz arka plan
      ),
      style: const TextStyle(
        fontSize: 14,
        color: Colors.white, // ✅ Beyaz yazı
        fontWeight: FontWeight.w500,
      ),
      items: availableCategories.map<DropdownMenuItem<String>>((category) {
        return DropdownMenuItem<String>(
          value: category['name'],
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              category['name'] ?? l10n.templateCategoryDropdownUnknownCategory,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white, // ✅ Dropdown item'ları da beyaz
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
      onChanged: onCategoryChanged,
      hint: Text(
        l10n.templateCategoryDropdownHint,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7), // ✅ Beyaz hint
          fontSize: 14,
        ),
      ),
    );
  }
}