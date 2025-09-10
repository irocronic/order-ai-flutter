class UnitConverter {
  static final Map<String, Map<String, double>> _conversionRules = {
    // Ağırlık birimi ailesi
    'kg': {
      'gr': 1000,    // 1 kg = 1000 gr
      'kg': 1,       // 1 kg = 1 kg
    },
    
    // Hacim birimi ailesi  
    'lt': {
      'ml': 1000,    // 1 lt = 1000 ml
      'cl': 100,     // 1 lt = 100 cl
      'lt': 1,       // 1 lt = 1 lt
    },
    
    // Sayılabilir birimler
    'adet': {
      'adet': 1,     // 1 adet = 1 adet
    },
    
    // Gram birimi (küçük malzemeler)
    'gr': {
      'gr': 1,       // 1 gr = 1 gr
      'mg': 1000,    // 1 gr = 1000 mg
    }
  };
  
  // Birim ailesini belirle
  static String getUnitFamily(String unit) {
    for (String family in _conversionRules.keys) {
      if (_conversionRules[family]!.containsKey(unit.toLowerCase())) {
        return family;
      }
    }
    return unit; // Eğer bulamazsa kendisini döndür
  }
  
  // Dönüştürülebilir birimleri getir
  static List<String> getCompatibleUnits(String baseUnit) {
    String family = getUnitFamily(baseUnit.toLowerCase());
    return _conversionRules[family]?.keys.toList() ?? [baseUnit];
  }
  
  // Birim dönüşümü yap
  static double convertToBaseUnit(double value, String fromUnit, String toUnit) {
    String family = getUnitFamily(toUnit.toLowerCase());
    double? fromFactor = _conversionRules[family]?[fromUnit.toLowerCase()];
    double? toFactor = _conversionRules[family]?[toUnit.toLowerCase()];
    
    if (fromFactor == null || toFactor == null) return value;
    
    return (value * toFactor) / fromFactor;
  }
  
  // Sayıyı formatla
  static String formatNumber(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    } else {
      return value.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
  }
}