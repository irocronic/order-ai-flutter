// lib/screens/stock_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/stock_movement.dart';
import '../services/stock_service.dart'; // Yeni servis

class StockHistoryScreen extends StatefulWidget {
  final String token;
  final int stockId; // Ana Stock objesinin ID'si
  final String variantFullName; // Başlıkta göstermek için

  const StockHistoryScreen({
    Key? key,
    required this.token,
    required this.stockId,
    required this.variantFullName,
  }) : super(key: key);

  @override
  _StockHistoryScreenState createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends State<StockHistoryScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<StockMovement> _movements = [];
  DateTimeRange? _selectedDateRange;
  String? _selectedMovementType;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final movements = await StockService.fetchStockMovements(
        token: widget.token,
        stockId: widget.stockId,
        movementType: _selectedMovementType,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );
      if (mounted) {
        setState(() {
          _movements = movements;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchHistory();
    }
  }

  String _getMovementTypeDisplay(BuildContext context, String movementKey) {
    final l10n = AppLocalizations.of(context)!;
    switch (movementKey) {
      case 'INITIAL': return l10n.stockHistoryMovementTypeInitial;
      case 'ADDITION': return l10n.stockMovementAddition; // DÜZELTİLDİ
      case 'SALE': return l10n.stockHistoryMovementTypeSale;
      case 'RETURN': return l10n.stockHistoryMovementTypeReturn;
      case 'ADJUSTMENT_IN': return l10n.stockHistoryMovementTypeAdjIn;
      case 'ADJUSTMENT_OUT': return l10n.stockHistoryMovementTypeAdjOut;
      case 'WASTAGE': return l10n.stockHistoryMovementTypeWastage;
      case 'MANUAL_EDIT': return l10n.stockHistoryMovementTypeManual;
      default: return movementKey;
    }
  }

  Widget _buildFilters(AppLocalizations l10n) {
    // Filtre için hareket tipleri (Django modelindekiyle uyumlu)
    final Map<String, String> movementTypeOptions = {
      '': l10n.stockHistoryMovementTypeAll,
      'INITIAL': l10n.stockHistoryMovementTypeInitial,
      'ADDITION': l10n.stockMovementAddition, // DÜZELTİLDİ
      'SALE': l10n.stockHistoryMovementTypeSale,
      'RETURN': l10n.stockHistoryMovementTypeReturn,
      'ADJUSTMENT_IN': l10n.stockHistoryMovementTypeAdjIn,
      'ADJUSTMENT_OUT': l10n.stockHistoryMovementTypeAdjOut,
      'WASTAGE': l10n.stockHistoryMovementTypeWastage,
      'MANUAL_EDIT': l10n.stockHistoryMovementTypeManual,
    };

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Colors.white.withOpacity(0.85),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.stockHistoryFiltersTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _selectedDateRange == null
                            ? l10n.stockHistorySelectDateRange
                            : l10n.stockHistoryDateRangeDisplay(
                                DateFormat('dd/MM/yy').format(_selectedDateRange!.start),
                                DateFormat('dd/MM/yy').format(_selectedDateRange!.end),
                              ),
                      ),
                      onPressed: _pickDateRange,
                    ),
                  ),
                  if (_selectedDateRange != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        setState(() {
                          _selectedDateRange = null;
                        });
                        _fetchHistory();
                      },
                    ),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _selectedMovementType ?? '',
                decoration: InputDecoration(
                    labelText: l10n.stockHistoryMovementTypeLabel,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                ),
                items: movementTypeOptions.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMovementType = (value == null || value.isEmpty) ? null : value;
                  });
                  _fetchHistory();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stockHistoryScreenTitle(widget.variantFullName)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade900.withOpacity(0.9),
                Colors.blue.shade400.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            _buildFilters(l10n),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.orangeAccent)))
                      : _movements.isEmpty
                          ? Center(child: Text(l10n.stockHistoryNoMovements, style: const TextStyle(color: Colors.white70)))
                          : RefreshIndicator(
                              onRefresh: _fetchHistory,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _movements.length,
                                itemBuilder: (context, index) {
                                  final movement = _movements[index];
                                  Color changeColor = movement.quantityChange >= 0 ? Colors.green.shade700 : Colors.red.shade700;
                                  IconData movementIcon = Icons.swap_horiz;
                                  switch(movement.movementType) {
                                    case 'INITIAL': movementIcon = Icons.fiber_new; break;
                                    case 'ADDITION': movementIcon = Icons.add_circle_outline; break;
                                    case 'SALE': movementIcon = Icons.remove_circle_outline; break;
                                    case 'RETURN': movementIcon = Icons.undo; break;
                                    case 'ADJUSTMENT_IN': movementIcon = Icons.arrow_upward; break;
                                    case 'ADJUSTMENT_OUT': movementIcon = Icons.arrow_downward; break;
                                    case 'WASTAGE': movementIcon = Icons.delete_sweep; break;
                                    case 'MANUAL_EDIT': movementIcon = Icons.edit_note; break;
                                  }

                                  return Card(
                                    color: Colors.white.withOpacity(0.85),
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: changeColor.withOpacity(0.2),
                                        child: Icon(movementIcon, color: changeColor, size: 24),
                                      ),
                                      title: Text(
                                        l10n.stockHistoryMovementTitle(
                                          _getMovementTypeDisplay(context, movement.movementType),
                                          '${movement.quantityChange > 0 ? "+" : ""}${movement.quantityChange}',
                                        ),
                                        style: TextStyle(fontWeight: FontWeight.bold, color: changeColor),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(l10n.stockHistoryQuantityChange(
                                            movement.quantityBefore.toString(),
                                            movement.quantityAfter.toString(),
                                          )),
                                          Text(l10n.stockHistoryDateLabel(DateFormat('dd/MM/yyyy HH:mm').format(movement.timestamp.toLocal()))),
                                          if (movement.userUsername != null)
                                            Text(l10n.stockHistoryUserLabel(movement.userUsername!)),
                                          if (movement.description != null && movement.description!.isNotEmpty)
                                            Text(l10n.stockHistoryDescriptionLabel(movement.description!)),
                                          if (movement.relatedOrderId != null)
                                            Text(l10n.stockHistoryRelatedOrderLabel(movement.relatedOrderId.toString())),
                                        ],
                                      ),
                                      isThreeLine: (movement.description != null && movement.description!.isNotEmpty) || movement.relatedOrderId != null,
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}