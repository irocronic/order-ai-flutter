// lib/widgets/select_extra_dialog.dart

import 'package:flutter/material.dart';
import 'package:collection/collection.dart'; // firstWhereOrNull için
import '../models/menu_item.dart';
import '../models/menu_item_variant.dart';
import '../services/api_service.dart';
// OrderService'ı import et
import '../services/order_service.dart';

/// Mevcut bir sipariş kalemine ekstra eklemek için kullanılan diyalog.
class SelectExtraDialog extends StatefulWidget {
  final String token;
  final dynamic orderItem; // Ekstra eklenecek sipariş kalemi
  // --- YENİ PARAMETRE ---
  final int orderId; // Ana siparişin ID'si
  // --- /YENİ PARAMETRE ---
  final List<MenuItem> allMenuItems; // Tüm menü öğeleri varyantları bulmak için
  final VoidCallback onExtraAdded; // Ekstra eklendiğinde çağrılır (parent listeyi yeniler)

  const SelectExtraDialog({
    Key? key,
    required this.token,
    required this.orderItem,
    required this.orderId, // <<< Constructor'a eklendi
    required this.allMenuItems,
    required this.onExtraAdded,
  }) : super(key: key);

  @override
  _SelectExtraDialogState createState() => _SelectExtraDialogState();
}

class _SelectExtraDialogState extends State<SelectExtraDialog> {
  // İlgili ürünün ekstra varyantlarını bulur
  List<MenuItemVariant> get extraVariants {
    // Bu kısım aynı kalıyor
    final product = widget.orderItem['menu_item'];
    final matchingProduct = widget.allMenuItems.firstWhereOrNull((m) => m.id == product['id']);

    if (matchingProduct != null && matchingProduct.variants != null) {
      return matchingProduct.variants!.where((v) => v.isExtra).toList();
    }
    return [];
  }

  // Varyant için görsel widget'ı.
  Widget _buildVariantImage(MenuItemVariant variant, {double size = 40}) {
    // Bu kısım aynı kalıyor
    if (variant.image.isNotEmpty) {
      final url = variant.image.startsWith('http')
          ? variant.image
          : '${ApiService.baseUrl}${variant.image}';
      return Image.network(url, width: size, height: size, fit: BoxFit.cover);
    }
    return Icon(Icons.image_not_supported, size: size);
  }

  // Ekstra ekleme API çağrısı - OrderService kullanacak
  Future<void> _addExtra(MenuItemVariant variant) async {
    // Bu kısım güncellendi
    try {
      final response = await OrderService.addExtraToOrderItem(
        token: widget.token,
        // --- DEĞİŞİKLİK: widget.orderId kullanıldı ---
        orderId: widget.orderId,
        // --- /DEĞİŞİKLİK ---
        orderItemId: widget.orderItem['id'], // 'id' sipariş kaleminde bulunmalı
        variant: variant, // Seçilen ekstra varyant
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ekstra başarıyla eklendi.')),
          );
        }
        widget.onExtraAdded(); // Parent'ı listeyi yenilemesi için bilgilendir
        if (mounted) Navigator.of(context).pop(); // Modalı kapat
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ekstra eklenirken hata: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bu kısım aynı kalıyor
    if (extraVariants.isEmpty) {
      return AlertDialog(
        title: const Text('Ekstra Seçenek Yok'),
        content: const Text('Bu ürün için ekstra seçenek bulunamadı.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: Colors.white.withOpacity(0.9), // Yarı saydam beyaz
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Ekstra Seç', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: extraVariants.length,
          itemBuilder: (context, index) {
            final variant = extraVariants[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
              child: ListTile(
                leading: _buildVariantImage(variant, size: 40), // Varyant görseli
                title: Text('${variant.name} - ${variant.price} TL'),
                onTap: () {
                  _addExtra(variant); // Güncellenmiş _addExtra metodu çağırılıyor
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
      ],
    );
  }
}