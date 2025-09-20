// lib/widgets/table_layout/element_editor.dart

import 'package:flutter/material.dart';
import '../../models/layout_element.dart';

// GÜNCELLENDİ: Provider importları ve bağımlılığı kaldırıldı.
class ElementEditor extends StatefulWidget {
  final LayoutElement element;
  // YENİ: Değişiklikler kaydedildiğinde çağrılacak callback.
  final Function(LayoutElement) onSave;

  const ElementEditor({
    Key? key,
    required this.element,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ElementEditor> createState() => _ElementEditorState();
}

class _ElementEditorState extends State<ElementEditor> {
  late TextEditingController _textController;
  late double _fontSize;
  late bool _isBold;
  late Color _color;
  late double _width;
  late double _height;
  late double _rotation;

  final List<Color> _presetColors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.element.content);
    _fontSize = widget.element.fontSize;
    _isBold = widget.element.isBold;
    _color = widget.element.color;
    _width = widget.element.size.width;
    _height = widget.element.size.height;
    _rotation = widget.element.rotation;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // GÜNCELLENDİ: Provider'a doğrudan erişim yerine callback kullanılıyor.
  void _applyChanges() {
    // Stilleri içeren map'i güncelle.
    final newStyleProperties = Map<String, dynamic>.from(widget.element.styleProperties);
    newStyleProperties['content'] = _textController.text;
    newStyleProperties['fontSize'] = _fontSize;
    newStyleProperties['isBold'] = _isBold;
    newStyleProperties['color'] = _color.value;

    // `copyWith` ile güncellenmiş yeni bir element nesnesi oluştur.
    final updatedElement = widget.element.copyWith(
      size: Size(_width, _height),
      rotation: _rotation,
      styleProperties: newStyleProperties,
    );

    // Değişikliği parent widget'a bildir.
    widget.onSave(updatedElement);

    Navigator.of(context).pop();
  }

  Widget _buildColorPickerRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presetColors.map((c) {
        final bool selected = c.value == _color.value;
        return GestureDetector(
          onTap: () => setState(() => _color = c),
          child: Container(
            width: 32,
            height: 24,
            decoration: BoxDecoration(
              color: c,
              border: Border.all(color: selected ? Colors.black : Colors.grey.shade300, width: selected ? 2 : 1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Metin Düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textController,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'Metin'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Font boyutu:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    min: 8,
                    max: 72,
                    divisions: 64,
                    value: _fontSize.clamp(8.0, 72.0),
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
                Text(_fontSize.toInt().toString()),
              ],
            ),
            Row(
              children: [
                const Text('Kalın:'),
                const SizedBox(width: 8),
                Switch(value: _isBold, onChanged: (v) => setState(() => _isBold = v)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Renk:'),
                const SizedBox(width: 8),
                Expanded(child: _buildColorPickerRow()),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Genişlik:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    min: 20,
                    max: 800,
                    value: _width.clamp(20.0, 800.0),
                    onChanged: (v) => setState(() => _width = v),
                  ),
                ),
                Text(_width.toInt().toString()),
              ],
            ),
            Row(
              children: [
                const Text('Yükseklik:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    min: 8,
                    max: 600,
                    value: _height.clamp(8.0, 600.0),
                    onChanged: (v) => setState(() => _height = v),
                  ),
                ),
                Text(_height.toInt().toString()),
              ],
            ),
            Row(
              children: [
                const Text('Dönüş:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 360,
                    value: _rotation % 360,
                    onChanged: (v) => setState(() => _rotation = v),
                  ),
                ),
                Text('${_rotation.toInt()}°'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('İptal')),
        ElevatedButton(onPressed: _applyChanges, child: const Text('Kaydet')),
      ],
    );
  }
}