// lib/widgets/waiting_customers_modal.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../controllers/waiting_customers_controller.dart';
import '../widgets/waiting_customers/add_customer_form.dart';
import '../widgets/waiting_customers/waiting_customer_table.dart';
import '../widgets/waiting_customers/dialogs/waiting_customer_dialogs.dart';
import '../utils/notifiers.dart';

class WaitingCustomersModal extends StatefulWidget {
  final String token;
  final VoidCallback onCustomerListUpdated;

  const WaitingCustomersModal({
    Key? key,
    required this.token,
    required this.onCustomerListUpdated,
  }) : super(key: key);

  @override
  _WaitingCustomersModalState createState() => _WaitingCustomersModalState();
}

class _WaitingCustomersModalState extends State<WaitingCustomersModal> {
  // GÜNCELLEME: Controller nullable yapıldı, didChangeDependencies içinde başlatılacak.
  late WaitingCustomersController _controller;
  bool _isControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    // GÜNCELLEME: Controller başlatma işlemi didChangeDependencies'e taşındı.
    waitingListChangeNotifier.addListener(_handleWaitingListUpdate);
  }

  // YENİ: didChangeDependencies metodu eklendi
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Bu metodun sadece bir kez çalışmasını sağlıyoruz.
    if (!_isControllerInitialized) {
      final l10n = AppLocalizations.of(context)!;
      _controller = WaitingCustomersController(
        token: widget.token,
        l10n: l10n, // <<< YENİ: l10n nesnesi Controller'a burada veriliyor
        onStateUpdate: () {
          if (mounted) setState(() {});
        },
        showSnackBarCallback: (message, {isError = false}) {
          if (mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: isError ? Colors.redAccent : Colors.green,
                duration: Duration(seconds: isError ? 3 : 2),
              ),
            );
          }
        },
        onListRefreshed: widget.onCustomerListUpdated,
      );
      _isControllerInitialized = true;
    }
  }

  @override
  void dispose() {
    waitingListChangeNotifier.removeListener(_handleWaitingListUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _handleWaitingListUpdate() {
    final data = waitingListChangeNotifier.value;
    if (data != null && mounted) {
      debugPrint("WaitingCustomersModal: waitingListChangeNotifier tetiklendi. Event: ${data['event_type']}");
      _controller.refreshList().then((_) {});
    }
  }

  void _showEditDialog(dynamic customer) {
    WaitingCustomerDialogs.showEditCustomerDialog(
      context: context,
      customer: customer,
      onConfirm: (int custId, String name, String phone, bool isWaiting, int partySize, String notes) async {
        await _controller.updateCustomer(custId, name, phone, isWaiting, partySize, notes);
      },
    );
  }

  void _showDeleteDialog(dynamic customerId) {
    WaitingCustomerDialogs.showDeleteConfirmationDialog(
      context: context,
      customerId: customerId as int,
      onConfirm: (id) async => await _controller.deleteCustomer(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInsets = MediaQuery.of(context).viewInsets.bottom;
    
    // Controller'ın başlatıldığından emin olmak için bir kontrol ekliyoruz
    if (!_isControllerInitialized) {
        return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInsets),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.98),
              Colors.blue.shade500.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius:
              const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, -5))],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.waitingCustomersTitle,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white54, height: 20),
              if (_controller.showAddForm)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: AddCustomerForm(
                    nameController: _controller.nameController,
                    phoneController: _controller.phoneController,
                    partySizeController: _controller.partySizeController,
                    notesController: _controller.notesController,
                    onAddCustomer: _controller.addCustomer,
                    isLoading: _controller.isAddingCustomer,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.8),
                        foregroundColor: Colors.blue.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                      ),
                      onPressed: () => _controller.toggleAddForm(true),
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                      label: Text(l10n.addNewCustomerButtonLabel),
                    ),
                  ),
                ),
              
              if (_controller.errorMessage.isNotEmpty && !_controller.isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _controller.errorMessage,
                    style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

              Flexible(
                child: _controller.isLoading && _controller.waitingCustomers.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : RefreshIndicator(
                        onRefresh: _controller.refreshList,
                        color: Colors.white,
                        backgroundColor: Colors.blue.shade700,
                        child: _controller.waitingCustomers.isEmpty && _controller.errorMessage.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                                  child: Text(
                                    l10n.waitingCustomerTableNoCustomers,
                                    style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 16),
                                  ),
                                ),
                              )
                            : WaitingCustomerTable(
                                customers: _controller.waitingCustomers,
                                onEdit: _showEditDialog,
                                onDelete: (customer) => _showDeleteDialog(customer['id']),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}