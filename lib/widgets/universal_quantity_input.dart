// lib/widgets/universal_quantity_input.dart

import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../utils/unit_converter.dart';

class UniversalQuantityInput extends StatefulWidget {
  final Ingredient? selectedIngredient;
  final Function(double) onQuantityChanged;
  final String? initialValue;
  
  const UniversalQuantityInput({
    Key? key,
    required this.selectedIngredient,
    required this.onQuantityChanged,
    this.initialValue,
  }) : super(key: key);

  @override
  _UniversalQuantityInputState createState() => _UniversalQuantityInputState();
}

class _UniversalQuantityInputState extends State<UniversalQuantityInput> {
  late TextEditingController _quantityController;
  String _selectedDisplayUnit = '';
  
  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.initialValue ?? '');
    _updateDisplayUnit();
  }
  
  @override
  void didUpdateWidget(UniversalQuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIngredient != widget.selectedIngredient) {
      _updateDisplayUnit();
    }
  }
  
  void _updateDisplayUnit() {
    if (widget.selectedIngredient != null) {
      String baseUnit = widget.selectedIngredient!.unitAbbreviation.toLowerCase();
      List<String> compatibleUnits = UnitConverter.getCompatibleUnits(baseUnit);
      
      // Kullanıcı dostu varsayılan birim seç
      if (compatibleUnits.contains('gr')) {
        _selectedDisplayUnit = 'gr'; // Ağırlık için gram
      } else if (compatibleUnits.contains('ml')) {
        _selectedDisplayUnit = 'ml'; // Hacim için mililitre
      } else {
        _selectedDisplayUnit = compatibleUnits.first; // Diğerleri için ilk birim
      }
      
      if (mounted) setState(() {});
    }
  }
  
  List<String> _getAvailableUnits() {
    if (widget.selectedIngredient == null) return [];
    
    String baseUnit = widget.selectedIngredient!.unitAbbreviation.toLowerCase();
    return UnitConverter.getCompatibleUnits(baseUnit);
  }
  
  double _getConvertedValue() {
    double inputValue = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 0;
    if (widget.selectedIngredient == null) return inputValue;
    
    String baseUnit = widget.selectedIngredient!.unitAbbreviation.toLowerCase();
    return UnitConverter.convertToBaseUnit(inputValue, _selectedDisplayUnit, baseUnit);
  }
  
  String _getConversionText() {
    if (widget.selectedIngredient == null) return '';
    
    double inputValue = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 0;
    if (inputValue <= 0) return '';
    
    String baseUnit = widget.selectedIngredient!.unitAbbreviation;
    if (_selectedDisplayUnit.toLowerCase() == baseUnit.toLowerCase()) return '';
    
    double convertedValue = _getConvertedValue();
    return '= ${UnitConverter.formatNumber(convertedValue)} $baseUnit';
  }
  
  @override
  Widget build(BuildContext context) {
    List<String> availableUnits = _getAvailableUnits();
    String conversionText = _getConversionText();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Miktar girişi
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Miktar',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon: const Icon(Icons.scale),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {});
                  widget.onQuantityChanged(_getConvertedValue());
                },
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Miktar gerekli';
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Geçerli bir sayı girin';
                  }
                  return null;
                },
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Birim seçici
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String>(
                value: availableUnits.contains(_selectedDisplayUnit) ? _selectedDisplayUnit : null,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: availableUnits.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(unit.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDisplayUnit = value!;
                  });
                  widget.onQuantityChanged(_getConvertedValue());
                },
              ),
            ),
          ],
        ),
        
        // Dönüşüm gösterimi
        if (conversionText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                conversionText,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
  
  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}