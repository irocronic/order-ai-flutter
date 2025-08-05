// lib/controllers/takeaway_order_screen_controller.dart

import 'package:flutter/foundation.dart';
import '../services/order_service.dart';
import '../services/connectivity_service.dart';
import '../services/cache_service.dart';
import '../models/order.dart' as AppOrder;
import '../models/paginated_response.dart';
// --- YENİ: Gerekli importlar ---
import '../models/menu_item.dart';

/// TakeawayOrderScreen için state ve iş mantığını yönetir.
class TakeawayOrderScreenController {
  final String token;
  final int businessId;
  final VoidCallback onStateUpdate;

  // --- YENİ: Menü ve kategori listeleri eklendi ---
  List<AppOrder.Order> takeawayOrders = [];
  List<MenuItem> menuItems = [];
  List<dynamic> categories = [];
  // --- /YENİ ---
  
  int currentPage = 1;
  bool hasNextPage = true;
  bool isFirstLoadRunning = false;
  bool isLoadMoreRunning = false;
  String errorMessage = '';

  TakeawayOrderScreenController({
    required this.token,
    required this.businessId,
    required this.onStateUpdate,
  });

  // --- GÜNCELLEME: Artık menü ve kategorileri de çekiyor ---
  Future<void> loadFirstPage() async {
    isFirstLoadRunning = true;
    _notifyUI();

    errorMessage = '';
    
    // Hem siparişleri hem de menü verilerini aynı anda çek
    try {
      final results = await Future.wait([
        OrderService.fetchTakeawayOrdersPaginated(token: token, page: 1),
        OrderService.fetchMenuItems(token),
        OrderService.fetchCategories(token),
      ]);

      final paginatedResponse = results[0] as PaginatedResponse<AppOrder.Order>;
      takeawayOrders = paginatedResponse.results;
      hasNextPage = paginatedResponse.next != null;
      currentPage = 1;

      final menuData = results[1] as List<dynamic>? ?? [];
      final categoryData = results[2] as List<dynamic>? ?? [];
      menuItems = menuData.map((e) => MenuItem.fromJson(e)).toList();
      categories = categoryData;
      
    } catch (e) {
      errorMessage = e.toString().replaceFirst("Exception: ", "");
    }

    isFirstLoadRunning = false;
    _notifyUI();
  }

  // loadMore metodu sadece siparişleri çekmeye devam edecek, bu doğru.
  Future<void> loadMore() async {
    if (hasNextPage && !isFirstLoadRunning && !isLoadMoreRunning) {
      isLoadMoreRunning = true;
      _notifyUI();

      currentPage++;
      // Burada sadece siparişleri çekmeye devam ediyoruz, bu kısım doğru.
      await _fetchOrdersOnly(page: currentPage);

      isLoadMoreRunning = false;
      _notifyUI();
    }
  }

  // loadMore için sadece siparişleri çeken yardımcı metot
  Future<void> _fetchOrdersOnly({required int page}) async {
    try {
      final response = await OrderService.fetchTakeawayOrdersPaginated(
        token: token,
        page: page,
      );
      
      takeawayOrders.addAll(response.results);
      hasNextPage = response.next != null;
      currentPage = page;

    } catch (e) {
      errorMessage = e.toString().replaceFirst("Exception: ", "");
      currentPage--; // Başarısız olursa sayfa numarasını geri al
    }
  }

  void _notifyUI() {
    onStateUpdate();
  }
}