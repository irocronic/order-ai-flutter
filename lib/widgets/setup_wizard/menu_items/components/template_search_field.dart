// lib/widgets/setup_wizard/menu_items/components/template_search_field.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TemplateSearchField extends StatelessWidget {
  final TextEditingController searchController;

  const TemplateSearchField({
    Key? key,
    required this.searchController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        labelText: l10n.searchProductLabel,
        hintText: l10n.searchProductHint,
        prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade600),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        isDense: true,
        labelStyle: const TextStyle(color: Colors.grey),
        hintStyle: TextStyle(color: Colors.grey.shade500),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: 16, color: Colors.grey.shade600),
                onPressed: () => searchController.clear(),
              )
            : null,
      ),
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }
}