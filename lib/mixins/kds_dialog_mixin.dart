// lib/mixins/kds_dialog_mixin.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/user_session.dart';
import '../widgets/dialogs/order_approved_for_kitchen_dialog.dart';
import '../widgets/dialogs/order_ready_for_pickup_dialog.dart';
import '../models/notification_event_types.dart';
import '../utils/notifiers.dart';
import '../main.dart';

mixin KdsDialogMixin<T extends StatefulWidget> on State<T> {
  // Dialog management properties
  bool isDialogShowing = false;
  bool dialogBlocked = false;
  Timer? dialogBlockTimer;
  final Set<String> activeDialogs = <String>{};
  bool isProcessingPending = false;
  
  // Pending notifications store
  List<Map<String, dynamic>> pendingNotifications = [];

  // Required getters - must be implemented by the using class
  String get kdsScreenSlug;
  bool get isDisposed;
  bool get isCurrent;
  bool get isAppInForeground;
  bool get isNavigationInProgress;
  
  // Required methods - must be implemented by the using class
  void safeRefreshDataWithThrottling();

  bool shouldProcessUpdate() {
    return mounted && isCurrent && isAppInForeground && !isDisposed;
  }

  bool shouldShowDialog() {
    return shouldProcessUpdate() && !dialogBlocked && !isDialogShowing && 
           !BuildLockManager.isLocked && NavigatorSafeZone.canNavigate();
  }

  void handleLoudNotification() {
    final data = newOrderNotificationDataNotifier.value;
    
    if (data == null || dialogBlocked || BuildLockManager.isLocked || NavigatorSafeZone.isBusy) {
      if (data != null) newOrderNotificationDataNotifier.value = null;
      return;
    }

    if (!shouldShowDialog()) {
      if (data != null) {
        debugPrint("[KdsScreen-$kdsScreenSlug] Ekran/dialog durumu uygun değil, bildirim bekletiliyor.");
        pendingNotifications.add(Map<String, dynamic>.from(data));
      }
      if (data != null) newOrderNotificationDataNotifier.value = null;
      return;
    }

    final String? eventType = data['event_type'] as String?;
    if (eventType == null || !UserSession.hasNotificationPermission(eventType)) {
      newOrderNotificationDataNotifier.value = null;
      return;
    }
    
    final String? kdsSlugInEvent = data['kds_slug'] as String?;
    if (kdsSlugInEvent != null && kdsSlugInEvent != kdsScreenSlug) {
      newOrderNotificationDataNotifier.value = null;
      return;
    }
    
    showNotificationDialog(data, eventType);
    newOrderNotificationDataNotifier.value = null;
  }

  void handleSocketOrderUpdate() {
    final data = orderStatusUpdateNotifier.value;
    if (data != null) {
      final String? eventType = data['event_type'] as String?;
      final String? kdsSlugInEvent = data['kds_slug'] as String?;

      if (kdsSlugInEvent == null || kdsSlugInEvent == kdsScreenSlug) {
        debugPrint("[KdsScreen-$kdsScreenSlug] 📡 Socket update received: '$eventType'");
        
        if (shouldProcessUpdate()) {
          debugPrint("[KdsScreen-$kdsScreenSlug] 🔄 Refreshing data...");
          safeRefreshDataWithThrottling();
        } else {
          debugPrint("[KdsScreen-$kdsScreenSlug] 📋 Screen inactive, adding to pending list.");
          pendingNotifications.add(Map<String, dynamic>.from(data));
        }
      } else {
        debugPrint("[KdsScreen-$kdsScreenSlug] 🚫 Event for other KDS ('$kdsSlugInEvent'), ignoring.");
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && orderStatusUpdateNotifier.value == data) {
          orderStatusUpdateNotifier.value = null;
        }
      });
    }
  }

  void processPendingNotifications() {
    if (isProcessingPending || isDisposed || !mounted) {
      debugPrint('[KdsScreen-$kdsScreenSlug] Pending processing blocked');
      return;
    }
    
    if (pendingNotifications.isEmpty) {
      debugPrint('[KdsScreen-$kdsScreenSlug] No pending notifications');
      return;
    }
    
    if (!shouldProcessUpdate() || dialogBlocked) {
      debugPrint('[KdsScreen-$kdsScreenSlug] Pending processing conditions not met');
      return;
    }
    
    isProcessingPending = true;
    debugPrint('[KdsScreen-$kdsScreenSlug] 📨 Processing ${pendingNotifications.length} pending notifications.');
    
    // Process first notification
    if (pendingNotifications.isNotEmpty) {
      final notification = pendingNotifications.removeAt(0);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isDisposed && mounted && shouldShowDialog()) {
          processNotificationSafely(notification);
        }
        
        // Process next notifications after short delay
        if (pendingNotifications.isNotEmpty && !isDisposed && mounted) {
          Timer(const Duration(milliseconds: 1500), () {
            isProcessingPending = false;
            processPendingNotifications();
          });
        } else {
          isProcessingPending = false;
        }
      });
    } else {
      isProcessingPending = false;
    }
  }

  void processNotificationSafely(Map<String, dynamic> data) {
    if (!shouldShowDialog()) return;
    
    final String? eventType = data['event_type'] as String?;
    if (eventType == null) return;
    
    showNotificationDialog(data, eventType);
  }

  void showNotificationDialog(Map<String, dynamic> data, String eventType) {
    if (!NavigatorSafeZone.canNavigate() || !shouldShowDialog()) return;
    
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null || !navigatorState.mounted) return;
    
    try {
      if (navigatorState.userGestureInProgress) {
        debugPrint('[KdsScreen] Navigator busy with user gesture, dialog skipped');
        return;
      }
    } catch (e) {
      debugPrint('[KdsScreen] Navigator state check failed: $e');
      return;
    }
    
    if (activeDialogs.contains(eventType)) {
      debugPrint("[KdsScreen-$kdsScreenSlug] Dialog type '$eventType' already active, skipping.");
      return;
    }
    
    final context = navigatorKey.currentContext ?? this.context;
    if (!mounted || context == null) return;
    
    Widget? dialogWidget;
    switch (eventType) {
      case NotificationEventTypes.orderApprovedForKitchen:
        dialogWidget = OrderApprovedForKitchenDialog(notificationData: data, onAcknowledge: () {});  
        break;
      case NotificationEventTypes.orderReadyForPickupUpdate:
        dialogWidget = OrderReadyForPickupDialog(notificationData: data, onAcknowledge: () {});
        break;
      case NotificationEventTypes.orderItemAdded:
        dialogWidget = OrderApprovedForKitchenDialog(notificationData: data, onAcknowledge: () {});
        break;
    }

    if (dialogWidget != null && !isDisposed && mounted) {
      debugPrint("[KdsScreen-$kdsScreenSlug] 📱 Bildirim diyalogu gösteriliyor: $eventType");
      
      NavigatorSafeZone.markBusy('dialog_show');
      
      isDialogShowing = true;
      activeDialogs.add(eventType);
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => dialogWidget!,
      ).then((_) {
        if (mounted && !isDisposed) {
          isDialogShowing = false;
          activeDialogs.remove(eventType);
          shouldRefreshTablesNotifier.value = true;
          debugPrint("[KdsScreen-$kdsScreenSlug] ✅ Dialog kapatıldı: $eventType");
        }
        NavigatorSafeZone.markFree('dialog_show');
      }).catchError((error) {
        debugPrint("[KdsScreen-$kdsScreenSlug] ❌ Dialog error: $error");
        if (mounted && !isDisposed) {
          isDialogShowing = false;
          activeDialogs.remove(eventType);
        }
        NavigatorSafeZone.markFree('dialog_show');
      });
    } else {
      NavigatorSafeZone.markFree('dialog_show');
    }
  }

  void blockDialogsTemporarily() {
    dialogBlocked = true;
    dialogBlockTimer?.cancel();
    
    dialogBlockTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !isDisposed) {
        dialogBlocked = false;
      }
    });
  }

  void unblockDialogs() {
    dialogBlockTimer?.cancel();
    dialogBlocked = false;
  }

  void cleanupDialogs() {
    dialogBlocked = true;
    isDialogShowing = false;
    activeDialogs.clear();
    
    NavigatorSafeZone.markBusy('dialog_cleanup');
    
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        Navigator.of(context).popUntil((route) {
          return route is! DialogRoute;
        });
      } catch (e) {
        debugPrint('[KdsScreen] Dialog cleanup error: $e');
      }
    }
    
    Timer(const Duration(milliseconds: 300), () {
      NavigatorSafeZone.markFree('dialog_cleanup');
    });
  }

  // Cleanup method to be called in dispose
  void disposeDialogMixin() {
    cleanupDialogs();
    dialogBlockTimer?.cancel();
    pendingNotifications.clear();
  }
}