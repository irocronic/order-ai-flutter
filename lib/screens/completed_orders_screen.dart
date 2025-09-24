// lib/screens/completed_orders_screen.dart

import '../services/notification_center.dart';
import '../services/refresh_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/order_service.dart';
import '../models/order.dart' as AppOrder;
import '../models/paginated_response.dart';
import 'order_detail_screen.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class _OrderDisplayData {
  final String title;
  final String subtitle;
  final double totalAmount;
  
  const _OrderDisplayData({
    required this.title,
    required this.subtitle,
    required this.totalAmount,
  });
}

class CompletedOrdersScreen extends StatefulWidget {
  final String token;
  final int businessId;
  
  const CompletedOrdersScreen({
    Key? key, 
    required this.token, 
    required this.businessId
  }) : super(key: key);

  @override
  _CompletedOrdersScreenState createState() => _CompletedOrdersScreenState();
}

class _CompletedOrdersScreenState extends State<CompletedOrdersScreen> {
  final ScrollController _scrollController = ScrollController();
  List<AppOrder.Order> _orders = [];
  final Map<int, _OrderDisplayData> _orderDisplayCache = {};
  
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isFirstLoadRunning = false;
  bool _isLoadMoreRunning = false;
  String _errorMessage = '';
 
  late AppLocalizations _l10n;
  bool _isL10nInitialized = false;

  String _formatDateToTurkeyTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return _l10n.completedOrdersUnknown;
    try {
      final utcDate = DateTime.parse(dateStr);
      final istanbul = tz.getLocation('Europe/Istanbul');
      final istanbulDate = tz.TZDateTime.from(utcDate, istanbul);
      return DateFormat('dd/MM/yyyy').format(istanbulDate);
    } catch (e) {
      debugPrint("Tarih formatlama hatası: $e");
      return _l10n.completedOrdersInvalidDate;
    }
  }
 
  String _getDisplayTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final utcDate = DateTime.parse(dateStr);
      final istanbul = tz.getLocation('Europe/Istanbul');
      final istanbulDate = tz.TZDateTime.from(utcDate, istanbul);
      return DateFormat('HH:mm').format(istanbulDate);
    } catch (e) {
      debugPrint("Saat formatlama hatası: $e");
      return '';
    }
  }

  String _getPaymentType(String? apiType) {
    switch (apiType) {
      case 'credit_card':
        return _l10n.paymentTypeCreditCard;
      case 'cash':
        return _l10n.paymentTypeCash;
      case 'food_card':
        return _l10n.paymentTypeFoodCard;
      default:
        return _l10n.paymentTypeUnknown;
    }
  }

  String _getPaymentDateStr(AppOrder.Order order) {
    final paymentInfo = order.payment as Map<String, dynamic>?;
    if (paymentInfo != null && paymentInfo['payment_date'] != null) {
      return paymentInfo['payment_date'];
    }
    return order.createdAt ?? '';
  }

  _OrderDisplayData _calculateOrderDisplayData(AppOrder.Order order) {
    // Order ID null kontrolü
    final orderId = order.id;
    if (orderId == null) {
      // ID yoksa cache kullanmayız, her seferinde hesaplarız
      return _createDisplayData(order);
    }

    // Cache kontrolü
    if (_orderDisplayCache.containsKey(orderId)) {
      return _orderDisplayCache[orderId]!;
    }

    final displayData = _createDisplayData(order);
    
    // Cache'e kaydet
    _orderDisplayCache[orderId] = displayData;
    return displayData;
  }

  _OrderDisplayData _createDisplayData(AppOrder.Order order) {
    // Hesaplamaları yap
    final totalAmount = order.orderItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final paymentInfo = order.payment as Map<String, dynamic>?;
    final paymentType = _getPaymentType(paymentInfo?['payment_type']);
    final paymentDateStr = _getPaymentDateStr(order);
    final displayDate = _formatDateToTurkeyTime(paymentDateStr);
    final displayTime = _getDisplayTime(paymentDateStr);

    final title = order.table != null
        ? _l10n.orderCardTitleTable(order.table.toString(), (order.id ?? 0).toString())
        : _l10n.orderCardTitleTakeaway((order.id ?? 0).toString());
        
    final subtitle = _l10n.orderCardSubtitleDetails(
      totalAmount.toStringAsFixed(2), 
      paymentType, 
      displayDate, 
      displayTime
    );

    return _OrderDisplayData(
      title: title,
      subtitle: subtitle,
      totalAmount: totalAmount,
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMore);
    
    NotificationCenter.instance.addObserver('refresh_all_screens', (data) {
      debugPrint('[CompletedOrdersScreen] 📡 Global refresh received: ${data['event_type']}');
      if (mounted && _isL10nInitialized) {
        final refreshKey = 'completed_orders_screen_${widget.businessId}';
        RefreshManager.throttledRefresh(refreshKey, () async {
          _orderDisplayCache.clear(); // Cache'i temizle
          await _loadFirstPage();
        });
      }
    });

    NotificationCenter.instance.addObserver('screen_became_active', (data) {
      debugPrint('[CompletedOrdersScreen] 📱 Screen became active notification received');
      if (mounted && _isL10nInitialized) {
        final refreshKey = 'completed_orders_screen_active_${widget.businessId}';
        RefreshManager.throttledRefresh(refreshKey, () async {
          _orderDisplayCache.clear(); // Cache'i temizle
          await _loadFirstPage();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isL10nInitialized) {
      _l10n = AppLocalizations.of(context)!;
      _isL10nInitialized = true;
      _loadFirstPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMore);
    _scrollController.dispose();
    _orderDisplayCache.clear(); // Cache'i temizle
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    setState(() {
      _isFirstLoadRunning = true;
      _errorMessage = '';
    });
    try {
      final response = await OrderService.fetchCompletedOrdersPaginated(
        token: widget.token, 
        page: 1
      );
      if (mounted) {
        setState(() {
          _orders = response.results;
          _hasNextPage = response.next != null;
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isFirstLoadRunning = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_hasNextPage && 
        !_isFirstLoadRunning && 
        !_isLoadMoreRunning && 
        _scrollController.position.extentAfter < 300) {
      if (!mounted) return;
      setState(() => _isLoadMoreRunning = true);
      _currentPage += 1;
      try {
        final response = await OrderService.fetchCompletedOrdersPaginated(
          token: widget.token, 
          page: _currentPage
        );
        if (mounted) {
          setState(() {
            _orders.addAll(response.results);
            _hasNextPage = response.next != null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n.completedOrdersErrorLoadMore), 
              backgroundColor: Colors.redAccent
            )
          );
        }
        _currentPage -= 1;
      } finally {
        if (mounted) {
          setState(() => _isLoadMoreRunning = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isL10nInitialized) {
      return Scaffold(
        backgroundColor: Colors.blue.shade900,
        body: const Center(child: CircularProgressIndicator(color: Colors.white))
      );
    }
   
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _l10n.completedOrdersTitle, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF283593), Color(0xFF455A64)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900.withOpacity(0.9), Colors.blue.shade400.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _buildContent(),
      )
    );
  }

  Widget _buildContent() {
    if (_isFirstLoadRunning) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    
    if (_errorMessage.isNotEmpty && _orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage, 
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 16), 
            textAlign: TextAlign.center
          )
        )
      );
    }
    
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          _orderDisplayCache.clear();
          await _loadFirstPage();
        },
        color: Colors.white,
        backgroundColor: Colors.blue.shade700,
        child: Stack(
          children: [
            ListView(),
            Center(
              child: Text(
                _l10n.completedOrdersNoOrdersFound, 
                style: const TextStyle(color: Colors.white70)
              )
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _orderDisplayCache.clear();
        await _loadFirstPage();
      },
      color: Colors.white,
      backgroundColor: Colors.blue.shade700,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12.0),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400.0,
          mainAxisSpacing: 12.0,
          crossAxisSpacing: 12.0,
          childAspectRatio: 1.6,
        ),
        itemCount: _orders.length + (_isLoadMoreRunning ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _orders.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          }
          
          final order = _orders[index];
          final displayData = _calculateOrderDisplayData(order);
           
          return Card(
            color: Colors.white.withOpacity(0.8),
            elevation: 4,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailScreen(order: order),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayData.title, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    Text(
                      displayData.subtitle,
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        _l10n.orderCardDetailsButton,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}