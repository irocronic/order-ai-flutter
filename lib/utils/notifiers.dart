// lib/utils/notifiers.dart
import 'package:flutter/material.dart';

/// SafeValueNotifier: ValueNotifier'ın dispose sonrası kullanılmasını engelleyen
/// küçük bir sarmalayıcı. dispose edilmiş bir SafeValueNotifier'a yazma/okuma
/// veya listener ekleme/çıkarma girişimleri sessizce bastırılır ve debug log
/// bırakılır. Böylece "used after dispose" hatalarının önüne geçilir.
class SafeValueNotifier<T> extends ValueNotifier<T> {
  bool _isDisposed = false;

  SafeValueNotifier(T value) : super(value);

  @override
  void addListener(VoidCallback listener) {
    if (_isDisposed) {
      debugPrint('[SafeValueNotifier] addListener suppressed (disposed).');
      return;
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_isDisposed) {
      debugPrint('[SafeValueNotifier] removeListener suppressed (disposed).');
      return;
    }
    super.removeListener(listener);
  }

  @override
  set value(T newValue) {
    if (_isDisposed) {
      debugPrint('[SafeValueNotifier] write suppressed (disposed). Value: $newValue');
      return;
    }
    try {
      super.value = newValue;
    } catch (e) {
      debugPrint('[SafeValueNotifier] write error: $e');
    }
  }

  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) {
      debugPrint('[SafeValueNotifier] dispose() already called.');
      return;
    }
    _isDisposed = true;
    try {
      super.dispose();
    } catch (e) {
      debugPrint('[SafeValueNotifier] dispose error: $e');
    }
  }
}

// Global notifiers (artık SafeValueNotifier ile)
final SafeValueNotifier<bool> shouldRefreshTablesNotifier = SafeValueNotifier<bool>(false);
final SafeValueNotifier<Map<String, dynamic>?> newOrderNotificationDataNotifier = SafeValueNotifier<Map<String, dynamic>?>(null);
final SafeValueNotifier<Map<String, dynamic>?> orderStatusUpdateNotifier = SafeValueNotifier<Map<String, dynamic>?>(null);
final SafeValueNotifier<Map<String, dynamic>?> waitingListChangeNotifier = SafeValueNotifier<Map<String, dynamic>?>(null);
final SafeValueNotifier<bool> shouldRefreshWaitingCountNotifier = SafeValueNotifier<bool>(false);
final SafeValueNotifier<Map<String, dynamic>?> pagerStatusUpdateNotifier = SafeValueNotifier<Map<String, dynamic>?>(null);
final SafeValueNotifier<Map<String, dynamic>?> informationalNotificationNotifier = SafeValueNotifier<Map<String, dynamic>?>(null);
final SafeValueNotifier<String?> syncStatusMessageNotifier = SafeValueNotifier<String?>(null);
final SafeValueNotifier<bool> stockAlertNotifier = SafeValueNotifier<bool>(false);
final SafeValueNotifier<Map<String, dynamic>?> kdsUpdateNotifier = SafeValueNotifier<Map<String, dynamic>?>(null);