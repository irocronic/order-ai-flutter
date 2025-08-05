// lib/screens/manage_variant_list_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/api_service.dart';
import 'manage_variant_screen.dart';

class ManageVariantListScreen extends StatefulWidget {
  final String token;
  final int businessId;

  const ManageVariantListScreen({
    Key? key,
    required this.token,
    required this.businessId,
  }) : super(key: key);

  @override
  _ManageVariantListScreenState createState() => _ManageVariantListScreenState();
}

class _ManageVariantListScreenState extends State<ManageVariantListScreen> {
  bool isLoading = true;
  String errorMessage = '';
  List<dynamic> menuItems = [];
  bool _didFetchData = false;

  @override
  void initState() {
    super.initState();
    // initState içinde fetchMenuItems çağrısı kaldırıldı.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Bu metodun sadece bir kez çalışmasını sağlamak için kontrol ekliyoruz.
    if (!_didFetchData) {
      fetchMenuItems();
      _didFetchData = true;
    }
  }

  Future<void> fetchMenuItems() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final url = ApiService.getUrl('/menu-items/');
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer ${widget.token}"},
      );
      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
          setState(() {
            // Sadece varyantı olan ürünleri listele
            menuItems = data.where((item) => item['business'] == widget.businessId && (item['variants'] as List).isNotEmpty).toList();
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = l10n.manageVariantListErrorLoading;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if(mounted) {
        setState(() {
          errorMessage = l10n.errorGeneral(e.toString());
          isLoading = false;
        });
      }
    }
  }

  Widget _buildMenuItemCard(dynamic menuItem, AppLocalizations l10n) {
    final imageUrl = (menuItem['image'] != null && menuItem['image'].toString().isNotEmpty)
        ? menuItem['image'].toString().startsWith('http') 
          ? menuItem['image'] 
          : ApiService.baseUrl + menuItem['image']
        : null;

    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ManageVariantScreen(
                token: widget.token,
                menuItemId: menuItem['id'],
              ),
            ),
          );
          fetchMenuItems();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    )
                  : Icon(Icons.restaurant_menu, size: 50, color: Colors.grey.shade700),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                menuItem['name'] ?? l10n.unknownProduct,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String displayErrorMessage = errorMessage; // Hata mesajı zaten lokalize

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.manageVariantListScreenTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF283593),
                Color(0xFF455A64),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : errorMessage.isNotEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(displayErrorMessage, style: const TextStyle(color: Colors.orangeAccent, fontSize: 16), textAlign: TextAlign.center),
                    ))
                  : RefreshIndicator(
                      onRefresh: fetchMenuItems,
                      color: Colors.white,
                      backgroundColor: Colors.blue.shade700,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200, // Her bir kartın maksimum genişliği
                          childAspectRatio: 0.9,   // En/boy oranı
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16
                        ),
                        itemCount: menuItems.length,
                        itemBuilder: (context, index) {
                          final menuItem = menuItems[index];
                          return _buildMenuItemCard(menuItem, l10n);
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}