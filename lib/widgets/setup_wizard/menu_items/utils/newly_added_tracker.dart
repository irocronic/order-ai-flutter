// lib/widgets/setup_wizard/menu_items/utils/newly_added_tracker.dart
class NewlyAddedTracker {
  static final Set<int> _newlyAddedItems = <int>{};

  /// Bir ürünün yeni eklenen olup olmadığını kontrol et
  static bool isNewlyAdded(int itemId) {
    return _newlyAddedItems.contains(itemId);
  }

  /// Yeni eklenen ürünleri işaretle
  static void markAsNewlyAdded(Set<int> itemIds) {
    _newlyAddedItems.addAll(itemIds);
    
    // 10 saniye sonra temizle
    if (_newlyAddedItems.isNotEmpty) {
      Future.delayed(const Duration(seconds: 10), () {
        _newlyAddedItems.clear();
      });
    }
  }

  /// Tek bir ürünü yeni eklenen olarak işaretle
  static void markSingleItemAsNew(int itemId) {
    _newlyAddedItems.add(itemId);
    
    // 10 saniye sonra temizle
    Future.delayed(const Duration(seconds: 10), () {
      _newlyAddedItems.remove(itemId);
    });
  }

  /// Yeni eklenen ürünleri manuel olarak temizle
  static void clearNewlyAddedItems() {
    _newlyAddedItems.clear();
  }

  /// Yeni eklenen ürün sayısını al
  static int get newlyAddedCount => _newlyAddedItems.length;

  /// Tüm yeni eklenen ürün ID'lerini al
  static Set<int> get newlyAddedItems => Set<int>.from(_newlyAddedItems);
}