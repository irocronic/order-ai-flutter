// lib/providers/table_layout_provider.dart

import 'package:flutter/material.dart';
import '../models/business_layout.dart';
import '../models/table_model.dart';
import '../models/layout_element.dart';
import '../models/shape_style.dart';
import '../services/layout_service.dart';
import '../services/user_session.dart';

class TableLayoutProvider extends ChangeNotifier {
  BusinessLayout? _layout;
  List<TableModel> _placedTables = [];
  List<TableModel> _unplacedTables = [];
  List<LayoutElement> _elements = [];

  bool _isLoading = true;
  String _errorMessage = '';
  
  dynamic _selectedItem;

  BusinessLayout? get layout => _layout;
  List<TableModel> get placedTables => _placedTables;
  List<TableModel> get unplacedTables => _unplacedTables;
  List<LayoutElement> get elements => _elements;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  dynamic get selectedItem => _selectedItem;

  // Hata düzeltmesi: Provider'ın dispose edilip edilmediğini takip etmek için bir bayrak.
  bool _isDisposed = false;

  TableLayoutProvider() {
    fetchLayoutData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> fetchLayoutData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final fetchedLayout = await LayoutService.fetchLayout(UserSession.token);
      if (_isDisposed) return; // Async işlem sonrası kontrol
      _layout = fetchedLayout;
      _elements = fetchedLayout.elements;

      _placedTables = fetchedLayout.tables.where((t) => t.posX != null && t.posY != null).toList();
      _unplacedTables = fetchedLayout.tables.where((t) => t.posX == null || t.posY == null).toList();

    } catch (e) {
      _errorMessage = 'Yerleşim planı yüklenemedi: $e';
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
  
  void selectItem(dynamic item) {
    _selectedItem = item;
    notifyListeners();
  }

  void deselectAll() {
    _selectedItem = null;
    notifyListeners();
  }
  
  void placeTableOnCanvas(TableModel table, Offset position) {
    _unplacedTables.removeWhere((t) => t.id == table.id);
    table.posX = position.dx;
    table.posY = position.dy;
    _placedTables.add(table);
    selectItem(table);
    notifyListeners();
  }

  void updateTablePosition(TableModel table, Offset delta) {
    final index = _placedTables.indexWhere((t) => t.id == table.id);
    if (index != -1) {
      final currentTable = _placedTables[index];
      currentTable.posX = (currentTable.posX ?? 0) + delta.dx;
      currentTable.posY = (currentTable.posY ?? 0) + delta.dy;
      notifyListeners();
    }
  }

  void updateDroppedElementPosition(LayoutElement element, Offset position) {
    final index = _elements.indexWhere((e) => e == element);
    if (index != -1) {
      _elements[index].position = position;
      notifyListeners();
    }
  }

  void addElement(LayoutElementType type, String content, ShapeType? shapeType) {
    final newElement = LayoutElement(
      type: type,
      position: const Offset(100, 100),
      size: type == LayoutElementType.text 
            ? const Size(150, 30) 
            : (shapeType == ShapeType.line ? const Size(100, 4) : const Size(100, 100)),
      styleProperties: type == LayoutElementType.text
        ? {'content': content, 'fontSize': 18.0, 'color': Colors.black.value, 'isBold': false}
        : ShapeStyle(shapeType: shapeType ?? ShapeType.rectangle).toJson(),
    );
    _elements.add(newElement);
    selectItem(newElement);
    notifyListeners();
  }

  void updateElementPosition(LayoutElement element, Offset delta) {
    final index = _elements.indexWhere((e) => e == element);
    if (index != -1) {
      final currentElement = _elements[index];
      currentElement.position += delta;
      notifyListeners();
    }
  }

  /// Yeni: LayoutElement'in çeşitli alanlarını atomik şekilde günceller.
  /// styleUpdates: styleProperties içine eklenecek/overwrite edilecek alanlar.
  void updateElementProperties(
    LayoutElement element, {
    Offset? position,
    Size? size,
    double? rotation,
    Map<String, dynamic>? styleUpdates,
  }) {
    final index = _elements.indexWhere((e) => e == element);
    if (index == -1) return;

    final current = _elements[index];

    if (position != null) current.position = position;
    if (size != null) current.size = size;
    if (rotation != null) current.rotation = rotation;

    if (styleUpdates != null && styleUpdates.isNotEmpty) {
      // mevcut styleProperties'ı güncelle
      final updatedStyle = Map<String, dynamic>.from(current.styleProperties);
      updatedStyle.addAll(styleUpdates);
      current.styleProperties = updatedStyle;
    }

    notifyListeners();
  }
  
  void deleteSelectedItem() {
    if (_selectedItem == null) return;

    if (_selectedItem is TableModel) {
      final table = _selectedItem as TableModel;
      _placedTables.removeWhere((t) => t.id == table.id);
      table.posX = null;
      table.posY = null;
      _unplacedTables.add(table);
    } else if (_selectedItem is LayoutElement) {
      final element = _selectedItem as LayoutElement;
      _elements.remove(element);
    }
    
    _selectedItem = null;
    notifyListeners();
  }
  
  Future<void> saveLayout() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final results = await Future.wait([
        LayoutService.bulkUpdateTablePositions(UserSession.token, _placedTables),
        LayoutService.bulkUpdateLayoutElements(UserSession.token, _elements),
      ]);
      
      final updatedElements = results[1] as List<LayoutElement>;
      
      if (_isDisposed) return; // Async işlem sonrası kontrol
      
      _elements = updatedElements;
      // Başarılıysa errorMessage boş bırakılıyor (UI mevcut logic'ine göre boş => başarı).
      _errorMessage = '';
      
    } catch (e) {
      _errorMessage = 'Masa düzeni kaydedilemedi: $e';
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
        
        // Mesajı bir süre sonra temizle
        Future.delayed(const Duration(seconds: 3), () {
          // HATA DÜZELTMESİ: `_isDisposed` kontrolü eklendi.
          if (!_isDisposed) {
            _errorMessage = '';
            notifyListeners();
          }
        });
      }
    }
  }
}