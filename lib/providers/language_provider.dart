// lib/providers/language_provider.dart
import 'package:flutter/material.dart';
import '../services/cache_service.dart'; // Mevcut cache servisinizi kullanıyoruz

class LanguageProvider extends ChangeNotifier {
  // Uygulama genelinde kullanılacak olan dil bilgisini tutar.
  Locale? _currentLocale;

  Locale? get currentLocale => _currentLocale;

  // YENİ: Statik bir getter ekleyerek mevcut dil koduna anında erişim sağlayalım.
  // Bu, uygulamanın herhangi bir yerinden o anki dil kodunu kolayca almanızı sağlar.
  static String get currentLanguageCode =>
      CacheService.instance.settingsBox.get('selected_language_code') ?? 'tr';

  // Başlangıçta kaydedilmiş dili yükler.
  Future<void> loadLocale() async {
    // Hive/shared_preferences'ten kaydedilmiş dil kodunu oku
    final String? languageCode = CacheService.instance.settingsBox.get('selected_language_code');
    
    if (languageCode != null && languageCode.isNotEmpty) {
      _currentLocale = Locale(languageCode);
    } else {
      // Kayıtlı bir dil yoksa, null bırakarak Flutter'ın sistem dilini kullanmasını sağlarız.
      _currentLocale = null;
    }
    // Değişikliği dinleyen widget'lara haber verme (ilk yükleme için gerekmeyebilir ama zararı olmaz)
    notifyListeners(); 
  }

  // Kullanıcı yeni bir dil seçtiğinde bu metot çağrılır.
  Future<void> setLocale(Locale newLocale) async {
    // Yeni dili cihaz hafızasına kaydet
    await CacheService.instance.settingsBox.put('selected_language_code', newLocale.languageCode);
    
    // Uygulama state'ini güncelle
    _currentLocale = newLocale;
    
    // Bu değişikliği tüm dinleyen widget'lara bildirerek arayüzün anında güncellenmesini sağla.
    notifyListeners();
  }

  // Kayıtlı dil tercihini temizler ve sistem diline dönülmesini sağlar.
  Future<void> clearLocale() async {
      await CacheService.instance.settingsBox.delete('selected_language_code');
      _currentLocale = null;
      notifyListeners();
  }
}