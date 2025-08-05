// lib/controllers/waiting_customers_controller.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // YENİ: Yerelleştirme importu
import '../services/waiting_customer_service.dart';
import '../utils/notifiers.dart';

/// WaitingCustomersModal'ın state'ini ve iş mantığını yönetir.
class WaitingCustomersController {
  final String token;
  final Function() onStateUpdate;
  final Function(String message, {bool isError}) showSnackBarCallback;
  final Function() onListRefreshed;
  // YENİ: Lokalizasyon nesnesi eklendi
  final AppLocalizations l10n;

  List<dynamic> waitingCustomers = [];
  bool isLoading = true;
  bool isAddingCustomer = false;
  bool showAddForm = false;
  String errorMessage = '';
  Timer? _timer;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController partySizeController = TextEditingController(text: '1');
  final TextEditingController notesController = TextEditingController();


  WaitingCustomersController({
    required this.token,
    required this.onStateUpdate,
    required this.showSnackBarCallback,
    required this.onListRefreshed,
    required this.l10n, // YENİ: Constructor'a eklendi
  }) {
    refreshList();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_mounted) {
        onStateUpdate();
      } else {
        timer.cancel();
      }
    });
  }

  bool get mounted => _mounted;
  bool _mounted = true;


  Future<void> refreshList() async {
    if (!_mounted) return;
    _setLoading(true);
    try {
      final response = await WaitingCustomerService.fetchCustomers(token);
      if (!_mounted) return;

      if (response.statusCode == 200) {
        waitingCustomers = jsonDecode(utf8.decode(response.bodyBytes));
        errorMessage = '';
        onListRefreshed();
      } else {
        // GÜNCELLEME: Yerelleştirilmiş hata mesajı
        errorMessage = l10n.waitingCustomerErrorFetchList(response.statusCode.toString(), utf8.decode(response.bodyBytes));
        waitingCustomers = [];
      }
    } catch (e) {
      if (!_mounted) return;
      // GÜNCELLEME: Yerelleştirilmiş hata mesajı
      errorMessage = l10n.waitingCustomerErrorFetchListGeneric(e.toString());
      waitingCustomers = [];
    } finally {
      if (_mounted) _setLoading(false);
    }
  }

  Future<void> addCustomer() async {
    if (!_mounted) return;
    if (nameController.text.trim().isEmpty) {
      // GÜNCELLEME: Yerelleştirilmiş hata mesajı
      showSnackBarCallback(l10n.waitingCustomerErrorNameEmpty, isError: true);
      return;
    }
    int partySize = int.tryParse(partySizeController.text.trim()) ?? 1;
    if (partySize <= 0) {
      // GÜNCELLEME: Yerelleştirilmiş hata mesajı
      showSnackBarCallback(l10n.waitingCustomerErrorPartySizePositive, isError: true);
      return;
    }

    _setAddingCustomerLoading(true);
    try {
      final response = await WaitingCustomerService.addCustomer(
        token, 
        nameController.text.trim(), 
        phoneController.text.trim(),
        partySize,
        notesController.text.trim()
      );
      if (!_mounted) return;

      if (response.statusCode == 201) {
        // GÜNCELLEME: Yerelleştirilmiş başarı mesajı
        showSnackBarCallback(l10n.waitingCustomerSuccessAdd, isError: false);
        await refreshList();
        toggleAddForm(false);
        nameController.clear();
        phoneController.clear();
        partySizeController.text = '1';
        notesController.clear();
      } else {
        // GÜNCELLEME: Yerelleştirilmiş hata mesajı
        showSnackBarCallback(l10n.waitingCustomerErrorAdd(response.statusCode.toString(), utf8.decode(response.bodyBytes)), isError: true);
      }
    } catch (e) {
      if (!_mounted) return;
      // GÜNCELLEME: Yerelleştirilmiş hata mesajı
      showSnackBarCallback(l10n.waitingCustomerErrorAddGeneric(e.toString()), isError: true);
    } finally {
      if (_mounted) _setAddingCustomerLoading(false);
    }
  }

  Future<void> updateCustomer(int customerId, String name, String phone, bool isWaiting, int partySize, String notes) async {
    if (!_mounted) return;
    try {
      final response = await WaitingCustomerService.updateCustomer(
        token, 
        customerId, 
        name, 
        phone, 
        isWaiting,
        partySize,
        notes
      );
      if (!_mounted) return;

      if (response.statusCode == 200) {
        // GÜNCELLEME: Yerelleştirilmiş başarı mesajı
        showSnackBarCallback(l10n.waitingCustomerSuccessUpdate, isError: false);
        await refreshList();
      } else {
        // GÜNCELLEME: Yerelleştirilmiş hata mesajı
        showSnackBarCallback(l10n.waitingCustomerErrorUpdate(response.statusCode.toString(), utf8.decode(response.bodyBytes)), isError: true);
      }
    } catch (e) {
      if (!_mounted) return;
      // GÜNCELLEME: Yerelleştirilmiş hata mesajı
      showSnackBarCallback(l10n.waitingCustomerErrorUpdateGeneric(e.toString()), isError: true);
    }
  }

  Future<void> deleteCustomer(int customerId) async {
    if (!_mounted) return;
    // GÜNCELLEME: Yerelleştirilmiş bilgi mesajı
    showSnackBarCallback(l10n.waitingCustomerInfoDeleting, isError: false);
    try {
      final response = await WaitingCustomerService.deleteCustomer(token, customerId);
      if (!_mounted) return;

      if (response.statusCode == 204) {
        // GÜNCELLEME: Yerelleştirilmiş başarı mesajı
        showSnackBarCallback(l10n.waitingCustomerSuccessDelete, isError: false);
        await refreshList();
      } else {
        // GÜNCELLEME: Yerelleştirilmiş hata mesajı
        showSnackBarCallback(l10n.waitingCustomerErrorDelete(response.statusCode.toString(), utf8.decode(response.bodyBytes)), isError: true);
      }
    } catch (e) {
      if (!_mounted) return;
      // GÜNCELLEME: Yerelleştirilmiş hata mesajı
      showSnackBarCallback(l10n.waitingCustomerErrorDeleteGeneric(e.toString()), isError: true);
    }
  }

  void toggleAddForm(bool show) {
    if (!_mounted) return;
    showAddForm = show;
    if (!show) {
      nameController.clear();
      phoneController.clear();
      partySizeController.text = '1';
      notesController.clear();
    }
    onStateUpdate();
  }

  void _setLoading(bool value) {
    if (isLoading == value && !value && errorMessage.isEmpty) return;
    if (isLoading == value) return;

    isLoading = value;
    if (!value) {
      //
    }
    onStateUpdate();
  }

  void _setAddingCustomerLoading(bool value) {
    if (isAddingCustomer == value) return;
    isAddingCustomer = value;
    onStateUpdate();
  }

  void dispose() {
    _mounted = false;
    _timer?.cancel();
    nameController.dispose();
    phoneController.dispose();
    partySizeController.dispose();
    notesController.dispose();
    debugPrint("WaitingCustomersController disposed");
  }
}