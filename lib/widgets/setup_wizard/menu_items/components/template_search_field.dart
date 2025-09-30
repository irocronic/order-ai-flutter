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
        prefixIcon: Icon(Icons.search, size: 18, color: Colors.white.withOpacity(0.8)), // ✅ Beyaz icon
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        isDense: true,
        labelStyle: const TextStyle(color: Colors.white), // ✅ Beyaz label
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)), // ✅ Beyaz hint
        filled: true,
        fillColor: Colors.white.withOpacity(0.1), // ✅ Hafif beyaz arka plan
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: 16, color: Colors.white.withOpacity(0.8)), // ✅ Beyaz clear icon
                onPressed: () => searchController.clear(),
              )
            : null,
      ),
      style: const TextStyle(
        fontSize: 14,
        color: Colors.white, // ✅ Beyaz yazı
      ),
    );
  }
}