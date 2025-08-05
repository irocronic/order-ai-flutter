// lib/widgets/shared/offline_banner.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Bu widget için Provider paketi idealdir
import '../../services/connectivity_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ConnectivityService'i dinlemek için bir ValueListenableBuilder kullanıyoruz.
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnlineNotifier,
      builder: (context, isOnline, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isOnline ? 0 : 30, // Bağlantı yoksa yüksekliği 30 yap, varsa 0
          color: Colors.red.shade700,
          child: isOnline
              ? null
              : const Center(
                  child: Text(
                    'ÇEVRİMDIŞI MOD - Veriler yerel olarak kaydediliyor.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
        );
      },
    );
  }
}