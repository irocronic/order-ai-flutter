// lib/widgets/shared/sync_status_indicator.dart

import 'package:flutter/material.dart';
import '../../services/cache_service.dart';
import '../../services/connectivity_service.dart';
import 'sync_queue_details_modal.dart'; // Yeni oluşturulan modalı import et

/// Senkronizasyon kuyruğunda bekleyen işlem sayısını gösteren bir banner.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hem bağlantı durumunu hem de kuyruk sayısını dinle
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnlineNotifier,
      builder: (context, isOnline, child) {
        // Çevrimiçi ise bu banner'ı gösterme
        if (isOnline) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<int>(
          valueListenable: CacheService.instance.syncQueueCountNotifier,
          builder: (context, queueCount, child) {
            // ---- DEĞİŞİKLİK BAŞLANGICI ----
            // AnimatedContainer bir GestureDetector ile sarıldı.
            return GestureDetector(
              onTap: () {
                if (queueCount > 0) {
                  showDialog(
                    context: context,
                    builder: (_) => const SyncQueueDetailsModal(),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: queueCount > 0 ? 30 : 0, // Kuyrukta öğe varsa göster
                color: Colors.amber.shade800,
                child: queueCount == 0
                    ? null
                    : Center(
                        child: Text(
                          'Senkronize edilecek $queueCount işlem bekliyor.',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            );
            // ---- DEĞİŞİKLİK SONU ----
          },
        );
      },
    );
  }
}