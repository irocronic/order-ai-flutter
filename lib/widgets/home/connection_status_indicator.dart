// lib/widgets/home/connection_status_indicator.dart

import 'package:flutter/material.dart';
import '../../services/socket_service.dart';

class ConnectionStatusIndicator extends StatelessWidget {
  final SocketService socketService;
  final VoidCallback onTap;

  const ConnectionStatusIndicator({
    Key? key,
    required this.socketService,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: socketService.connectionStatusNotifier,
      builder: (context, status, child) {
        Color indicatorColor;
        IconData indicatorIcon;
        
        if (status == 'Bağlandı') {
          indicatorColor = Colors.green;
          indicatorIcon = Icons.wifi;
        } else if (status.contains('bekleniyor') || status.contains('deneniyor')) {
          indicatorColor = Colors.orange;
          indicatorIcon = Icons.wifi_tethering;
        } else {
          indicatorColor = Colors.red;
          indicatorIcon = Icons.wifi_off;
        }
        
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: indicatorColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                indicatorIcon,
                color: indicatorColor,
                size: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}