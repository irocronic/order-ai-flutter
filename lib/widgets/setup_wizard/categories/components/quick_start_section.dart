// lib/widgets/setup_wizard/categories/components/quick_start_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:convert';

import '../../../../services/api_service.dart';
import '../dialogs/category_template_selection_dialog.dart';
import '../dialogs/limit_reached_dialog.dart';

class QuickStartSection extends StatefulWidget {
  final String token;
  final int businessId;
  final int currentCategoryCount;
  final VoidCallback onCategoriesAdded;
  final Function(String, {bool isError}) onMessageChanged;

  const QuickStartSection({
    Key? key,
    required this.token,
    required this.businessId,
    required this.currentCategoryCount,
    required this.onCategoriesAdded,
    required this.onMessageChanged,
  }) : super(key: key);

  @override
  State<QuickStartSection> createState() => _QuickStartSectionState();
}

class _QuickStartSectionState extends State<QuickStartSection> {
  bool _isLoadingTemplates = false;

  Future<void> _showTemplateDialog() async {
    setState(() => _isLoadingTemplates = true);
    
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => CategoryTemplateSelectionDialog(
          onConfirm: (List<int> templateIds, int? kdsScreenId) async {
            try {
              debugPrint('📤 API çağrısı başlıyor: templateIds=$templateIds, kdsScreenId=$kdsScreenId');
              
              await ApiService.createCategoriesFromTemplates(
                widget.token,
                templateIds,
                kdsScreenId,
              );
              
              debugPrint('✅ API çağrısı başarılı');
              
              Navigator.of(dialogContext).pop({
                'success': true,
                'message': 'Kategoriler şablondan başarıyla oluşturuldu!',
                'count': templateIds.length,
              });
              
            } catch (e) {
              debugPrint('❌ API çağrısı hatalı: $e');
              Navigator.of(dialogContext).pop({
                'success': false,
                'message': 'Şablondan kategori oluşturulurken hata: ${e.toString()}',
              });
            }
          },
        ),
      );

      if (result != null && mounted) {
        final bool success = result['success'] ?? false;
        final String message = result['message'] ?? '';
        
        if (success) {
          debugPrint('🔄 Kategori listesi yenileniyor...');
          widget.onCategoriesAdded();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        debugPrint('ℹ️ Modal iptal edildi');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Şablonlar yüklenirken hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
            'Hazır şablonlardan kategori oluşturarak hızlıca başlayın!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: _isLoadingTemplates
                ? const SizedBox.shrink()
                : const Icon(Icons.add_to_photos_outlined),
            label: _isLoadingTemplates
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
                      Text(l10n.setupCategoriesAddFromTemplateButton),
                    ],
                  )
                : Text(l10n.setupCategoriesAddFromTemplateButton),
            onPressed: _isLoadingTemplates ? null : _showTemplateDialog,
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