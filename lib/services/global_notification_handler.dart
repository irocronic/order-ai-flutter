// lib/services/global_notification_handler.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:another_flushbar/flushbar.dart'; // YENİ: Paketi import et

import '../main.dart'; // navigatorKey için
import '../utils/notifiers.dart';
import '../services/user_session.dart';
import '../models/notification_event_types.dart';
import '../widgets/notifications/notification_ui_helper.dart';

class GlobalNotificationHandler {
  static bool _isBannerShowing = false;
  static final List<Map<String, dynamic>> _notificationQueue = [];

  static void initialize() {
    debugPrint("[GlobalNotificationHandler] Başlatıldı ve dinleyiciler ayarlandı.");
    newOrderNotificationDataNotifier.addListener(_handleNotification);
  }

  static void _handleNotification() {
    final data = newOrderNotificationDataNotifier.value;
    if (data == null) return;

    _notificationQueue.add(data);
    debugPrint("[GlobalNotificationHandler] Bildirim kuyruğa eklendi. Kuyruk boyutu: ${_notificationQueue.length}");
    newOrderNotificationDataNotifier.value = null;

    if (!_isBannerShowing) {
      _processNotificationQueue();
    }
  }

  static void _processNotificationQueue() {
    if (_isBannerShowing || _notificationQueue.isEmpty) {
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) {
      Future.delayed(const Duration(milliseconds: 500), _processNotificationQueue);
      return;
    }

    final data = _notificationQueue.removeAt(0);
    final String? eventType = data['event_type'] as String?;

    if (eventType == null || !UserSession.hasNotificationPermission(eventType)) {
      debugPrint("[GlobalNotificationHandler] Yetki yok veya event tipi belirsiz, bildirim atlanıyor.");
      _processNotificationQueue(); // Sıradaki bildirimi dene
      return;
    }

    if (!kIsWeb && _shouldPlaySound(eventType)) {
      try {
        FlutterRingtonePlayer().playNotification(asAlarm: true);
      } catch (e) {
        debugPrint("Bildirim sesi çalınırken hata: $e");
      }
    }

    _isBannerShowing = true;
    debugPrint("[GlobalNotificationHandler] Bildirim banner'ı gösteriliyor: $eventType");

    Flushbar(
      messageText: Text(
        data['message'] ?? 'Yeni bildirim!',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      icon: Icon(
        NotificationUiHelper.getIconForNotificationType(eventType),
        color: NotificationUiHelper.getIconColorForNotificationType(eventType),
        size: 32,
      ),
      duration: const Duration(seconds: 6),
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(12),
      backgroundColor: Colors.blueGrey.shade800.withOpacity(0.95),
      boxShadows: const [
        BoxShadow(
          color: Colors.black38,
          blurRadius: 10,
          offset: Offset(0, 4),
        )
      ],
      onStatusChanged: (status) {
        if (status == FlushbarStatus.DISMISSED) {
          _isBannerShowing = false;
          shouldRefreshTablesNotifier.value = true;
          debugPrint("[GlobalNotificationHandler] Banner kayboldu, shouldRefreshTablesNotifier tetiklendi.");
          _processNotificationQueue();
        }
      },
    ).show(context);
  }

  static bool _shouldPlaySound(String eventType) {
    const soundEvents = {
      NotificationEventTypes.guestOrderPendingApproval,
      NotificationEventTypes.existingOrderNeedsReapproval,
      NotificationEventTypes.orderApprovedForKitchen,
      NotificationEventTypes.orderReadyForPickupUpdate,
      NotificationEventTypes.orderItemAdded
    };
    return soundEvents.contains(eventType);
  }
}