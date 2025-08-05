// lib/screens/subscription_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/subscription_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// YENİ: Planların UI detaylarını organize etmek için bir yardımcı sınıf
class PlanUIDetails {
  final String title;
  final IconData icon;
  final Color color;
  final Map<String, String> limits;
  final ProductDetails? monthlyProduct;
  final ProductDetails? yearlyProduct;

  PlanUIDetails({
    required this.title,
    required this.icon,
    required this.color,
    required this.limits,
    this.monthlyProduct,
    this.yearlyProduct,
  });
}


class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = true;
  bool _isStoreAvailable = false;
  bool _isPurchasing = false; // YENİ: Satın alma işlemi sırasında UI'ı kilitlemek için

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    if (kIsWeb) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    await _subscriptionService.initialize();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isStoreAvailable = _subscriptionService.products.isNotEmpty;
      });
    }
  }

  // YENİ: Satın alma işlemini başlatan metot
  Future<void> _buy(ProductDetails product) async {
    setState(() => _isPurchasing = true);
    try {
      // Satın alma işlemi başarılı olursa servis zaten yönlendirme yapacak
      await _subscriptionService.buySubscription(product);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Satın alma sırasında bir hata oluştu: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        // Hata olsa bile veya kullanıcı iptal etse bile yükleniyor durumunu kapat
        setState(() => _isPurchasing = false);
      }
    }
  }

  // +++++++++ YENİ EKLENEN METOT +++++++++
  Future<void> _restorePurchases() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isPurchasing = true); // Geri yükleme sırasında da UI'ı kilitle
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.subscriptionRestoring)),
    );
    try {
      await _subscriptionService.restorePurchases();
      // Başarılı olursa, stream listener yönlendirmeyi yapacak.
      // Eğer stream'e hiçbir geri yükleme düşmezse, kullanıcıya bilgi verilebilir.
      // Bu genellikle in_app_purchase paketinin kendi içinde yönetilir.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }
  // +++++++++++++++++++++++++++++++++++++++

  @override
  void dispose() {
    _subscriptionService.dispose();
    super.dispose();
  }

  // YENİ: Mağazadan gelen ürünleri planlara göre gruplayan metot
  List<PlanUIDetails> _getGroupedPlans(AppLocalizations l10n) {
    ProductDetails? findProduct(String id) {
      try {
        return _subscriptionService.products.firstWhere((p) => p.id == id);
      } catch (e) {
        return null;
      }
    }

    return [
      PlanUIDetails(
        title: l10n.planBasic,
        icon: Icons.looks_one_outlined,
        color: Colors.blueGrey,
        limits: {
          l10n.maxTables: "10", l10n.maxStaff: "2", l10n.maxKdsScreens: "2",
          l10n.maxCategories: "4", l10n.maxMenuItems: "20", l10n.maxVariants: "50"
        },
        monthlyProduct: findProduct('aylik_abonelik_01'),
        yearlyProduct: findProduct('yillik_abonelik_01'),
      ),
      PlanUIDetails(
        title: l10n.planSilver,
        icon: Icons.looks_two_outlined,
        color: Colors.cyan.shade600,
        limits: {
          l10n.maxTables: "50", l10n.maxStaff: "10", l10n.maxKdsScreens: "4",
          l10n.maxCategories: "25", l10n.maxMenuItems: "100", l10n.maxVariants: "100"
        },
        monthlyProduct: findProduct('silver_aylik_paket_01'),
        yearlyProduct: findProduct('silver_yillik_paket_01'),
      ),
      PlanUIDetails(
        title: l10n.planGold,
        icon: Icons.looks_3_outlined,
        color: Colors.amber.shade700,
        limits: {
          l10n.maxTables: "120", l10n.maxStaff: "50", l10n.maxKdsScreens: "10",
          l10n.maxCategories: "100", l10n.maxMenuItems: "500", l10n.maxVariants: "1000"
        },
        monthlyProduct: findProduct('gold_aylik_paket_01'),
        yearlyProduct: findProduct('gold_yillik_paket_01'),
      ),
    ];
  }

  // YENİ: Her bir plan için kart oluşturan widget
  Widget _buildPlanCard(PlanUIDetails plan, AppLocalizations l10n) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: plan.color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(plan.icon, size: 40, color: plan.color),
            const SizedBox(height: 8),
            Text(plan.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: plan.color, fontWeight: FontWeight.bold)),
            const Divider(),
            ...plan.limits.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 14)),
                      Text(entry.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                )).toList(),
            const Spacer(),
            if (plan.monthlyProduct != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: plan.color, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(40)),
                onPressed: _isPurchasing ? null : () => _buy(plan.monthlyProduct!),
                child: Text("${plan.monthlyProduct!.price} / ${l10n.planMonthly}"),
              ),
            const SizedBox(height: 8),
            if (plan.yearlyProduct != null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(side: BorderSide(color: plan.color), foregroundColor: plan.color, minimumSize: const Size.fromHeight(40)),
                onPressed: _isPurchasing ? null : () => _buy(plan.yearlyProduct!),
                child: Text("${plan.yearlyProduct!.price} / ${l10n.planYearly}"),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final plans = _getGroupedPlans(l10n);

    Widget bodyContent;

    if (_isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (kIsWeb) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(l10n.subscriptionErrorWeb, textAlign: TextAlign.center),
        ),
      );
    } else if (!_isStoreAvailable) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            l10n.subscriptionErrorLoadingProducts,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.redAccent),
          ),
        ),
      );
    } else {
      bodyContent = Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: plans.length,
                  itemBuilder: (context, index) => _buildPlanCard(plans[index], l10n),
                );
              } else {
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => AspectRatio(
                    aspectRatio: 0.7,
                    child: _buildPlanCard(plans[index], l10n),
                  ),
                );
              }
            }
          ),
          if (_isPurchasing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      l10n.subscriptionPurchasing,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.subscriptionScreenTitle),
        // +++++++++ AppBar'a actions bölümü ekleniyor +++++++++
        actions: [
          if (!kIsWeb && _isStoreAvailable)
            TextButton(
              onPressed: _isPurchasing ? null : _restorePurchases,
              child: Text(
                l10n.subscriptionRestoreButton,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
        // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
      ),
      body: bodyContent,
    );
  }
}