// lib/utils/currency_formatter.dart

import 'package:intl/intl.dart';
import '../services/user_session.dart';

class CurrencyFormatter {
  
  /// Verilen para birimi koduna göre ilgili sembolü döndürür.
  static String getSymbol(String? currencyCode) {
    switch (currencyCode) {
      case 'TRY':
        return '₺';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '₺'; // Varsayılan veya bilinmeyen durumlar için
    }
  }

  /// Mevcut oturumdaki para birimi kodunu alarak sembolü döndürür.
  static String get currentSymbol {
    return getSymbol(UserSession.currencyCode);
  }

  /// Bir double değeri, belirtilen para birimine göre formatlar.
  static String format(double amount, {String? currencyCode}) {
    final code = currencyCode ?? UserSession.currencyCode;
    final format = NumberFormat.currency(
      locale: _getLocale(code),
      symbol: getSymbol(code),
    );
    return format.format(amount);
  }

  /// Para birimi koduna göre lokalizasyon (locale) bilgisini döndürür.
  static String _getLocale(String? currencyCode) {
    switch (currencyCode) {
      case 'TRY':
        return 'tr_TR';
      case 'USD':
        return 'en_US';
      case 'EUR':
        return 'de_DE';
      case 'GBP':
        return 'en_GB';
      default:
        return 'tr_TR';
    }
  }
}