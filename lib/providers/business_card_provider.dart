// lib/providers/business_card_provider.dart

// lib/providers/business_card_provider.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // YENİ IMPORT
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../models/business_card_model.dart';
import '../models/shape_style.dart';
import 'commands.dart';

// Hizalama çizgilerini temsil eden sınıf.
class AlignmentGuide {
  final double position;
  final Axis axis;
  AlignmentGuide(this.position, this.axis);
}

class BusinessCardProvider extends ChangeNotifier {
  BusinessCardModel _cardModel = BusinessCardModel.defaultCard();
  List<String> _selectedElementIds = [];
  bool _isShiftPressed = false;

  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];

  // Hizalama ve Kopyala/Yapıştır için state'ler
  List<AlignmentGuide> _activeGuides = [];
  List<CardElement> _clipboard = [];

  // YENİ EKLENEN DURUM: InteractiveViewer'ın pan özelliğini kontrol eder.
  bool _isCanvasPanningEnabled = true;

  BusinessCardModel get cardModel => _cardModel;
  List<String> get selectedElementIds => _selectedElementIds;
  bool get isShiftPressed => _isShiftPressed;
  List<AlignmentGuide> get activeGuides => _activeGuides;

  // YENİ EKLENDEN GETTER
  bool get isCanvasPanningEnabled => _isCanvasPanningEnabled;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // YENİ EKLENEN METOT: Kanvas etkileşimini açıp kapatır.
  void setCanvasPanning(bool isEnabled) {
    if (_isCanvasPanningEnabled != isEnabled) {
      _isCanvasPanningEnabled = isEnabled;
      notifyListeners();
    }
  }

  void setShiftPressedStatus(bool isPressed) {
    if (_isShiftPressed != isPressed) {
      _isShiftPressed = isPressed;
      notifyListeners();
    }
  }

  void setCardModelForCommand(BusinessCardModel model) {
    _cardModel = model;
    notifyListeners();
  }

  List<CardElement> get selectedElements {
    return _cardModel.elements
        .where((e) => _selectedElementIds.contains(e.id))
        .toList();
  }

  void execute(Command command) {
    final oldModel = _cardModel;
    command.execute();
    final newModel = _cardModel;

    if (!const DeepCollectionEquality().equals(oldModel, newModel)) {
      _undoStack.add(command);
      _redoStack.clear();
      notifyListeners();
    }
  }

  void undo() {
    if (canUndo) {
      final command = _undoStack.removeLast();
      command.undo();
      _redoStack.add(command);
      _selectedElementIds = [];
      notifyListeners();
    }
  }

  void redo() {
    if (canRedo) {
      final command = _redoStack.removeLast();
      command.execute();
      _undoStack.add(command);
      _selectedElementIds = [];
      notifyListeners();
    }
  }

  void updateModelForPreview(BusinessCardModel newModel) {
    _cardModel = newModel;
    notifyListeners();
  }

  void updateModel(BusinessCardModel oldModel, BusinessCardModel newModel) {
    final command = ModelUpdateCommand(this, oldModel, newModel);
    execute(command);
  }

  void selectElement(String? elementId, {bool addToSelection = false}) {
    if (elementId == null) {
      _selectedElementIds = [];
    } else {
      if (addToSelection || _isShiftPressed) {
        if (_selectedElementIds.contains(elementId)) {
          _selectedElementIds.remove(elementId);
        } else {
          _selectedElementIds.add(elementId);
        }
      } else {
        if (!_selectedElementIds.contains(elementId)) {
          _selectedElementIds = [elementId];
        }
      }
    }
    notifyListeners();
  }

  void updateAlignmentGuides(Rect draggedRect) {
    const snapThreshold = 4.0;
    final List<AlignmentGuide> guides = [];
    final otherElements =
        _cardModel.elements.where((e) => !_selectedElementIds.contains(e.id));

    for (var element in otherElements) {
      final staticRect = Rect.fromLTWH(element.position.dx,
          element.position.dy, element.size.width, element.size.height);

      if ((draggedRect.left - staticRect.left).abs() < snapThreshold)
        guides.add(AlignmentGuide(staticRect.left, Axis.vertical));
      if ((draggedRect.left - staticRect.right).abs() < snapThreshold)
        guides.add(AlignmentGuide(staticRect.right, Axis.vertical));
      if ((draggedRect.center.dx - staticRect.center.dx).abs() <
          snapThreshold)
        guides.add(AlignmentGuide(staticRect.center.dx, Axis.vertical));
      if ((draggedRect.right - staticRect.left).abs() < snapThreshold)
        guides.add(AlignmentGuide(staticRect.left, Axis.vertical));
      if ((draggedRect.right - staticRect.right).abs() < snapThreshold)
        guides.add(AlignmentGuide(staticRect.right, Axis.vertical));

      if ((draggedRect.top - staticRect.top).abs() < snapThreshold)
        guides.add(AlignmentGuide(staticRect.top, Axis.horizontal));
      if ((draggedRect.top - staticRect.bottom).abs() < snapThreshold)
        guides.add(AlignmentGuide(staticRect.bottom, Axis.horizontal));
      if ((draggedRect.center.dy - staticRect.center.dy).abs() <
          snapThreshold)
        guides.add(AlignmentGuide(staticRect.center.dy, Axis.horizontal));
      if ((draggedRect.bottom - staticRect.top).abs() < snapThreshold)
        guides.add(AlignmentGuide(staticRect.top, Axis.horizontal));
      if ((draggedRect.bottom - staticRect.bottom).abs() < snapThreshold)
        guides.add(AlignmentGuide(staticRect.bottom, Axis.horizontal));
    }

    _activeGuides = guides;
    notifyListeners();
  }

  void clearAlignmentGuides() {
    _activeGuides = [];
    notifyListeners();
  }

  void moveSelectedElements(Offset delta) {
    if (selectedElements.isEmpty) return;
    updateSelectedElementsProperties(
        (e) => e.copyWith(position: e.position + delta));
  }

  void copySelectedElements() {
    _clipboard =
        selectedElements.map((e) => CardElement.fromJson(e.toJson())).toList();
  }

  void pasteElements() {
    if (_clipboard.isEmpty) return;

    final oldModel = cardModel;
    final newElements = List<CardElement>.from(oldModel.elements);
    final uuid = Uuid();

    List<String> newSelectedIds = [];
    for (var element in _clipboard) {
      final newElement = element.copyWith(
        id: uuid.v4(),
        position: element.position + const Offset(10, 10),
      );
      newElements.add(newElement);
      newSelectedIds.add(newElement.id);
    }

    final newModel = oldModel.copyWith(elements: newElements);
    _selectedElementIds = newSelectedIds;
    updateModel(oldModel, newModel);
  }

  void reorderElement(int oldIndex, int newIndex) {
    final oldModel = cardModel;
    final elements = List<CardElement>.from(oldModel.elements);
    final element = elements.removeAt(oldIndex);

    if (newIndex > oldIndex) newIndex -= 1;
    elements.insert(newIndex, element);

    final newModel = oldModel.copyWith(elements: elements);
    updateModel(oldModel, newModel);
  }

  // GÜNCELLEME: Lokalizasyonlu metin için parametre eklendi
  void addTextElement({String? localizedText}) {
    final newElement = CardElement(
      id: Uuid().v4(),
      type: CardElementType.text,
      content: localizedText ?? 'New Text', // Fallback için İngilizce
      position: const Offset(20, 100),
      size: const Size(150, 25),
      style: const TextStyle(fontSize: 16, color: Colors.black, fontFamily: 'Roboto'),
    );
    final command = AddElementCommand(this, newElement);
    execute(command);
    selectElement(newElement.id);
  }

  void addShapeElement(ShapeType shapeType) {
    final newElement = CardElement(
      id: Uuid().v4(),
      type: CardElementType.shape,
      content: shapeType.name,
      position: const Offset(75, 75),
      size: shapeType == ShapeType.line
          ? const Size(100, 4)
          : const Size(100, 100),
      style: const TextStyle(),
      shapeStyle: ShapeStyle(
        shapeType: shapeType,
        fillColor: shapeType == ShapeType.line
            ? Colors.transparent
            : Colors.blue.withOpacity(0.7),
        borderColor: Colors.black,
        borderWidth: 4,
      ),
    );
    final command = AddElementCommand(this, newElement);
    execute(command);
    selectElement(newElement.id);
  }

  void addImageElement(Uint8List imageData) {
    final newElement = CardElement(
      id: Uuid().v4(),
      type: CardElementType.image,
      content: '',
      imageData: imageData,
      position: const Offset(50, 50),
      size: const Size(100, 100),
      style: const TextStyle(),
    );
    final command = AddElementCommand(this, newElement);
    execute(command);
    selectElement(newElement.id);
  }

  void addQrCodeElement(String data) {
    final newElement = CardElement(
      id: Uuid().v4(),
      type: CardElementType.qrCode,
      content: data,
      position: const Offset(50, 50),
      size: const Size(80, 80),
      style: const TextStyle(color: Colors.black),
    );
    final command = AddElementCommand(this, newElement);
    execute(command);
    selectElement(newElement.id);
  }

  Future<void> addSvgElement() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['svg'],
    );

    if (result != null && result.files.single.bytes != null) {
      final fileBytes = result.files.single.bytes!;
      final svgContent = utf8.decode(fileBytes);

      final newElement = CardElement(
        id: Uuid().v4(),
        type: CardElementType.svg,
        content: svgContent,
        imageData: null,
        position: const Offset(50, 50),
        size: const Size(100, 100),
        style: const TextStyle(),
      );
      final command = AddElementCommand(this, newElement);
      execute(command);
      selectElement(newElement.id);
    }
  }
  
  // YENİ EKLENDİ: FontAwesome ikonu ekleme metodu
  void addFontAwesomeIconElement(IconData iconData) {
    final newElement = CardElement(
      id: Uuid().v4(),
      type: CardElementType.fontAwesomeIcon,
      content: iconData.codePoint.toString(), // İkonun kodunu sakla
      position: const Offset(50, 50),
      size: const Size(40, 40),
      style: const TextStyle(color: Colors.black), // Varsayılan renk
    );
    final command = AddElementCommand(this, newElement);
    execute(command);
    selectElement(newElement.id);
  }

  void deleteSelectedElements() {
    if (_selectedElementIds.isNotEmpty) {
      final command = DeleteElementsCommand(this, selectedElements);
      execute(command);
      _selectedElementIds = [];
    }
  }

  void updateBackgroundColor(Color startColor,
      [Color? endColor, GradientType? type, bool clearGradient = false]) {
    final command = UpdateBackgroundColorCommand(
        this,
        cardModel.gradientStartColor,
        cardModel.gradientEndColor,
        cardModel.gradientType,
        startColor,
        endColor,
        type,
        clearGradient);
    execute(command);
  }

  void updateSelectedElementsProperties(
      CardElement Function(CardElement) updater) {
    if (selectedElements.isEmpty) return;
    final oldModel = cardModel;
    final newElements = oldModel.elements.map((element) {
      if (selectedElementIds.contains(element.id)) {
        return updater(element);
      }
      return element;
    }).toList();
    final newModel = oldModel.copyWith(elements: newElements);
    updateModel(oldModel, newModel);
  }

  Future<void> saveCard() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(_cardModel.toJson());
    await prefs.setString('saved_business_card', jsonString);
  }

  Future<void> saveCardAsTemplate(String templateName) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(_cardModel.toJson());
    final List<String> existing = prefs.getStringList('user_templates') ?? [];
    final newEntry = jsonEncode({'name': templateName, 'json': jsonString});
    existing.add(newEntry);
    await prefs.setStringList('user_templates', existing);
  }

  Future<void> loadCard() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('saved_business_card');
    if (jsonString != null) {
      loadCardFromJson(jsonString);
    }
  }

  void loadCardFromJson(String jsonString) {
    _cardModel = BusinessCardModel.fromJson(jsonDecode(jsonString));
    _undoStack.clear();
    _redoStack.clear();
    _selectedElementIds = [];
    notifyListeners();
  }
}