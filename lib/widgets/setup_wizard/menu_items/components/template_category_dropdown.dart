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
      dropdownColor: Colors.white,
      iconEnabledColor: Colors.grey.shade600,
      decoration: InputDecoration(
        labelText: l10n.templateCategoryDropdownLabel,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        isDense: true,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
      ),
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
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
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
      onChanged: onCategoryChanged,
      hint: Text(
        l10n.templateCategoryDropdownHint,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
    );
  }
}