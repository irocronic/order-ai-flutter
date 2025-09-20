// lib/providers/table_layout_provider.dart

import 'package:flutter/material.dart';
import '../models/business_layout.dart';
import '../models/table_model.dart';
import '../models/layout_element.dart';
import '../models/shape_style.dart';
// YENİ IMPORT
import '../models/i_layout_item.dart';
import '../services/layout_service.dart';
import '../services/user_session.dart';

class TableLayoutProvider extends ChangeNotifier {
  BusinessLayout? _layout;
  List<TableModel> _placedTables = [];
  List<TableModel> _unplacedTables = [];
  List<LayoutElement> _elements = [];

  bool _isLoading = true;
  String _errorMessage = '';

  // GÜNCELLENDİ: `dynamic` yerine tip-güvenli `ILayoutItem` kullanılıyor.
  ILayoutItem? _selectedItem;

  // YENİ: Canvas widget'ının global pozisyonunu ve boyutunu almak için.
  // Bu, sürükleme sırasındaki koordinat dönüşümleri için kritiktir.
  GlobalKey? canvasKey;

  bool _isGridVisible = true;
  bool _isSnappingEnabled = true;
  final double _gridSpacing = 20.0;

  bool get isGridVisible => _isGridVisible;
  bool get isSnappingEnabled => _isSnappingEnabled;
  double get gridSpacing => _gridSpacing;

  BusinessLayout? get layout => _layout;
  List<TableModel> get placedTables => _placedTables;
  List<TableModel> get unplacedTables => _unplacedTables;
  List<LayoutElement> get elements => _elements;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  // GÜNCELLENDİ: Getter tipi de güncellendi.
  ILayoutItem? get selectedItem => _selectedItem;

  bool _isDisposed = false;

  TableLayoutProvider() {
    fetchLayoutData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
  
  // YENİ METOT: UI tarafından canvas anahtarını provider'a set etmek için.
  void setCanvasKey(GlobalKey key) {
    canvasKey = key;
  }

  void toggleGridSnapping() {
    _isGridVisible = !_isGridVisible;
    _isSnappingEnabled = !_isSnappingEnabled;
    notifyListeners();
  }

  Offset _snapToGrid(Offset position) {
    if (!_isSnappingEnabled) {
      return position;
    }
    final dx = (position.dx / _gridSpacing).round() * _gridSpacing;
    final dy = (position.dy / _gridSpacing).round() * _gridSpacing;
    return Offset(dx, dy);
  }

  Future<void> fetchLayoutData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final fetchedLayout = await LayoutService.fetchLayout(UserSession.token);
      if (_isDisposed) return;
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

  // GÜNCELLENDİ: Parametre tipi `ILayoutItem` oldu.
  void selectItem(ILayoutItem? item) {
    _selectedItem = item;
    notifyListeners();
  }

  void deselectAll() {
    _selectedItem = null;
    notifyListeners();
  }

  void placeTableOnCanvas(TableModel table, Offset position) {
    _unplacedTables.removeWhere((t) => t.id == table.id);
    final snappedPosition = _snapToGrid(position);
    table.posX = snappedPosition.dx;
    table.posY = snappedPosition.dy;
    _placedTables.add(table);
    selectItem(table);
    notifyListeners();
  }
  
  void updateDroppedElementPosition(LayoutElement element, Offset position) {
    final index = _elements.indexWhere((e) => e == element);
    if (index != -1) {
      _elements[index].position = _snapToGrid(position);
      notifyListeners();
    }
  }

  // GÜNCELLENDİ: Sürükleme bittiğinde çağrılacak olan merkezi metot.
  // Parametre tipi `ILayoutItem` oldu.
  void updateItemPositionAfterDrag(ILayoutItem item, Offset finalPosition) {
    // Canvas'ın RenderBox'ını kullanarak global pozisyonu lokale çeviriyoruz.
    // Bu, `InteractiveViewer`'ın pan/zoom durumunu hesaba katar.
    final RenderBox? canvasRenderBox = canvasKey?.currentContext?.findRenderObject() as RenderBox?;
    if (canvasRenderBox == null) return;
    
    final localPosition = canvasRenderBox.globalToLocal(finalPosition);
    final snappedPosition = _snapToGrid(localPosition);

    if (item is TableModel) {
      final index = _placedTables.indexWhere((t) => t.id == item.id);
      if (index != -1) {
        _placedTables[index].posX = snappedPosition.dx;
        _placedTables[index].posY = snappedPosition.dy;
      }
    } else if (item is LayoutElement) {
      final index = _elements.indexWhere((e) => e.id == item.id);
      if (index != -1) {
        _elements[index].position = snappedPosition;
      }
    }
    notifyListeners();
  }

  void addElement(LayoutElementType type, String content, ShapeType? shapeType) {
    final newElement = LayoutElement(
      id: DateTime.now().millisecondsSinceEpoch,
      type: type,
      position: _snapToGrid(const Offset(100, 100)),
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

  void updateElementProperties(
      LayoutElement element, {
        Offset? position,
        Size? size,
        double? rotation,
        Map<String, dynamic>? styleUpdates,
      }) {
    final index = _elements.indexWhere((e) => e.id == element.id);
    if (index == -1) return;
    final current = _elements[index];
    if (position != null) current.position = position;
    if (size != null) current.size = size;
    if (rotation != null) current.rotation = rotation;
    if (styleUpdates != null && styleUpdates.isNotEmpty) {
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
      table.rotation = 0.0;
      _unplacedTables.add(table);
    } else if (_selectedItem is LayoutElement) {
      final element = _selectedItem as LayoutElement;
      _elements.removeWhere((e) => e.id == element.id);
    }
    _selectedItem = null;
    notifyListeners();
  }

  Future<void> saveLayout() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final List<TableModel> allTables = [..._placedTables, ..._unplacedTables];
      final results = await Future.wait([
        LayoutService.bulkUpdateTablePositions(UserSession.token, allTables),
        LayoutService.bulkUpdateLayoutElements(UserSession.token, _elements),
      ]);
      final updatedElements = results[1] as List<LayoutElement>;
      if (_isDisposed) return;
      _elements = updatedElements;
      await fetchLayoutData();
    } catch (e) {
      _errorMessage = 'Masa düzeni kaydedilemedi: $e';
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
        Future.delayed(const Duration(seconds: 3), () {
          if (!_isDisposed && _errorMessage.isNotEmpty) {
            _errorMessage = '';
            notifyListeners();
          }
        });
      }
    }
  }
}