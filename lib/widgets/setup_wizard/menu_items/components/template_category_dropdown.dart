// lib/widgets/setup_wizard/menu_items/components/template_category_dropdown.dart
import 'package:flutter/material.dart';

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
    return DropdownButtonFormField<String>(
      value: selectedCategoryName,
      isExpanded: true,
      dropdownColor: Colors.white,
      iconEnabledColor: Colors.grey.shade600,
      decoration: const InputDecoration(
        labelText: 'Kategori Seçin',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        isDense: true,
        labelStyle: TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
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
              category['name'] ?? 'Bilinmeyen Kategori',
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
      hint: const Text(
        'Kategori seçiniz...',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
    );
  }
}