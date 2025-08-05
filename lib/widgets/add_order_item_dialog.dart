// lib/widgets/add_order_item_dialog.dart

import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../models/menu_item_variant.dart';
import '../controllers/add_order_item_dialog_controller.dart';
import 'add_order_item/category_selectors.dart';
import 'add_order_item/product_selector.dart';
import 'add_order_item/table_user_selector.dart';
import 'add_order_item/variant_selector.dart';
import 'add_order_item/extra_selector.dart';
import 'add_order_item/action_buttons.dart';

/// Siparişe yeni ürün eklemek için kullanılan diyalog widget'ı.
class AddOrderItemDialog extends StatefulWidget {
  final String token; // Controller'a iletilmeyecek ama belki ileride lazım olur
  final List<MenuItem> allMenuItems;
  final List<dynamic> categories;
  final List<String> tableUsers;
  final Function(MenuItem item, MenuItemVariant? variant, List<MenuItemVariant> extras, String? tableUser) onItemsAdded;

  const AddOrderItemDialog({
    Key? key,
    required this.token, // Şimdilik kullanılmıyor ama parametre olarak kalabilir
    required this.allMenuItems,
    required this.categories,
    required this.tableUsers,
    required this.onItemsAdded,
  }) : super(key: key);

  @override
  _AddOrderItemDialogState createState() => _AddOrderItemDialogState();
}

class _AddOrderItemDialogState extends State<AddOrderItemDialog> {
  late AddOrderItemDialogController _controller;
  final _formKey = GlobalKey<FormState>();
  final ScrollController _productsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AddOrderItemDialogController(
      allMenuItems: widget.allMenuItems,
      categories: widget.categories,
      tableUsers: widget.tableUsers,
      onStateUpdate: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _productsScrollController.dispose();
    // _controller.dispose(); // Gerekliyse (ChangeNotifier vb. kullanılırsa)
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.95),
              Colors.blue.shade400.withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Yeni Ürün Ekle',
                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                   textAlign: TextAlign.center,
                 ),
                 const SizedBox(height: 16),

                 // --- Ayrılmış Widget'ları Kullan ---
                 CategorySelectors(controller: _controller),
                 const SizedBox(height: 16),
                 TableUserSelector(controller: _controller),
                 const SizedBox(height: 16),
                  const Text('Ürünler', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                 ProductSelector(controller: _controller, scrollController: _productsScrollController),
                 const SizedBox(height: 16),
                 VariantSelector(controller: _controller),
                 const SizedBox(height: 16),
                 ExtraSelector(controller: _controller),
                 const SizedBox(height: 20),
                 ActionButtons(
                    formKey: _formKey,
                    controller: _controller,
                    onItemsAdded: widget.onItemsAdded
                 ),
                 // --- Ayrılmış Widget'ların Sonu ---
               ],
             ),
           ),
         ),
       ),
     );
  }
}