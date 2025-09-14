// lib/widgets/manage_website/color_picker_field.dart


import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

// Hex renk kodunu Color nesnesine dönüştüren yardımcı fonksiyon
Color colorFromHex(String hexColor) {
  final hexCode = hexColor.replaceAll('#', '');
  return Color(int.parse('FF$hexCode', radix: 16));
}

// Color nesnesini Hex renk koduna dönüştüren yardımcı fonksiyon
String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
}

class ColorPickerField extends StatelessWidget {
  final String label;
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;

  const ColorPickerField({
    Key? key,
    required this.label,
    required this.currentColor,
    required this.onColorChanged,
  }) : super(key: key);

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Renk Seç'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: onColorChanged,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Tamam'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: GestureDetector(
        onTap: () => _showColorPicker(context),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: currentColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}