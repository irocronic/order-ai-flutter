// lib/utils/currency_formatter.dart

import 'package:intl/intl.dart';
import '../services/user_session.dart';

class CurrencyFormatter {
  /// Verilen miktarı, UserSession'dan gelen para birimi koduna göre ve
  /// istenen "SAYI [SEMBOL]" formatında döndürür.
  /// Örnek: format(123.45) -> "123,45 TL" veya "123.45 $"
  static String format(double amount) {
    final String currencyCode = UserSession.currencyCode ?? 'TRY';
    
    // GÜNCELLENDİ: Sayıyı formatlamak için özel bir NumberFormat oluşturuyoruz.
    // "tr_TR" lokasyonu, ondalık ayırıcının virgül (,) olmasını sağlar.
    final numberFormat = NumberFormat("#,##0.00", "tr_TR");
    final formattedAmount = numberFormat.format(amount);

    // GÜNCELLENDİ: Para birimi koduna göre doğru metni/simgesi alıyoruz.
    final String currencySymbol = _getCurrencySymbol(currencyCode);

    // GÜNCELLENDİ: Biçimlendirilmiş sayı, boşluk ve para birimi simgesini birleştiriyoruz.
    return '$formattedAmount $currencySymbol';
  }

  /// Para birimi koduna göre uygun metni/simgesi döndürür.
  static String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return '\$'; // İsterseniz 'USD' olarak da değiştirebilirsiniz.
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'TRY':
      default:
        // YENİ: Kullanıcının istediği 'TL' formatı.
        return 'TL';
    }
  }
}