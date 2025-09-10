// lib/widgets/setup_wizard/menu_items/components/quick_start_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:convert';

import '../../../../services/api_service.dart';
import '../dialogs/template_selection_dialog.dart';
import '../dialogs/limit_reached_dialog.dart';

class QuickStartSection extends StatefulWidget {
  final String token;
  final List<dynamic> availableCategories;
  final int currentMenuItemCount;
  final VoidCallback onMenuItemsAdded;
  final Function(String, {bool isError}) onMessageChanged;

  const QuickStartSection({
    Key? key,
    required this.token,
    required this.availableCategories,
    required this.currentMenuItemCount,
    required this.onMenuItemsAdded,
    required this.onMessageChanged,
  }) : super(key: key);

  @override
  State<QuickStartSection> createState() => _QuickStartSectionState();
}

class _QuickStartSectionState extends State<QuickStartSection> {
  bool _isLoadingTemplates = false;
  bool _isSubmittingMenuItem = false; // 🔄 EKLENDI

  Future<void> _showTemplateSelectionDialog() async {
    if (widget.availableCategories.isEmpty) return;
    
    setState(() => _isLoadingTemplates = true);

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => TemplateSelectionDialog(
          token: widget.token,
          availableCategories: widget.availableCategories,
          currentMenuItemCount: widget.currentMenuItemCount,
        ),
      );

      // 🔄 DÜZELTİLDİ: Gerçek API çağrısı yap
      if (result != null && result['selectedTemplateIds'] != null && result['targetCategoryId'] != null) {
        final selectedTemplateIds = result['selectedTemplateIds'] as List<int>;
        final targetCategoryId = result['targetCategoryId'] as int;
        
        setState(() => _isSubmittingMenuItem = true);
        
        try {
          final newItems = await ApiService.createMenuItemsFromTemplates(
            widget.token,
            templateIds: selectedTemplateIds,
            targetCategoryId: targetCategoryId,
          );
          
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            widget.onMessageChanged(
              l10n.setupMenuItemsSuccessAddedFromTemplate(newItems.length)
            );
            
            // 🔄 DÜZELTİLDİ: Verileri yenile
            widget.onMenuItemsAdded();
          }

        } catch (e) {
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            String rawError = e.toString().replaceFirst("Exception: ", "");
            final jsonStartIndex = rawError.indexOf('{');
            
            if (jsonStartIndex != -1) {
              try {
                final jsonString = rawError.substring(jsonStartIndex);
                final decodedError = jsonDecode(jsonString);

                if (decodedError is Map && decodedError['code'] == 'limit_reached') {
                  showDialog(
                    context: context,
                    builder: (ctx) => LimitReachedDialog(
                      title: l10n.dialogLimitReachedTitle,
                      message: decodedError['detail'],
                    ),
                  );
                } else {
                  widget.onMessageChanged(decodedError['detail'] ?? rawError, isError: true);
                }
              } catch (jsonError) {
                widget.onMessageChanged(rawError, isError: true);
              }
            } else {
              widget.onMessageChanged(rawError, isError: true);
            }
          }
        } finally {
          if (mounted) setState(() => _isSubmittingMenuItem = false);
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        widget.onMessageChanged(
          l10n.setupMenuItemsErrorLoadingTemplates(e.toString()),
          isError: true
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingTemplates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.withOpacity(0.7), Colors.teal.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            'Hızlı Başlangıç',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hazır şablonlardan ürün oluşturarak hızlıca başlayın!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: _isLoadingTemplates || _isSubmittingMenuItem // 🔄 DÜZELTİLDİ
                ? const SizedBox.shrink()
                : const Icon(Icons.add_to_photos_outlined),
            label: _isLoadingTemplates || _isSubmittingMenuItem // 🔄 DÜZELTİLDİ
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, 
                          color: Colors.teal.shade700
                        )
                      ),
                      const SizedBox(width: 8),
                      Text(_isSubmittingMenuItem 
                          ? 'Ürünler ekleniyor...' 
                          : l10n.setupMenuItemsAddFromTemplateButton),
                    ],
                  )
                : Text(l10n.setupMenuItemsAddFromTemplateButton),
            onPressed: _isLoadingTemplates || _isSubmittingMenuItem || widget.availableCategories.isEmpty // 🔄 DÜZELTİLDİ
                ? null 
                : _showTemplateSelectionDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.teal.shade700,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }
}