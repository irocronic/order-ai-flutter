// lib/widgets/notifications/notification_ui_helper.dart
import 'package:flutter/material.dart';
import '../../models/notification_event_types.dart';

class NotificationUiHelper {
  static IconData getIconForNotificationType(String? eventType) {
    switch (eventType) {
      case NotificationEventTypes.guestOrderPendingApproval:
      case NotificationEventTypes.orderPendingApproval:
      case NotificationEventTypes.existingOrderNeedsReapproval:
        return Icons.hourglass_top_rounded;
      case NotificationEventTypes.newApprovedOrder:
      case NotificationEventTypes.orderApprovedForKitchen:
        return Icons.restaurant_menu_outlined;
      case NotificationEventTypes.orderReadyForPickupUpdate:
        return Icons.ramen_dining_outlined;
      case NotificationEventTypes.waitingCustomerAdded:
        return Icons.person_add_alt_outlined;
      default:
        return Icons.notifications_active;
    }
  }

  static Color getIconColorForNotificationType(String? eventType) {
    switch (eventType) {
      case NotificationEventTypes.guestOrderPendingApproval:
      case NotificationEventTypes.orderPendingApproval:
      case NotificationEventTypes.existingOrderNeedsReapproval:
        return Colors.orange.shade300;
      case NotificationEventTypes.newApprovedOrder:
      case NotificationEventTypes.orderApprovedForKitchen:
        return Colors.green.shade300;
      case NotificationEventTypes.orderReadyForPickupUpdate:
        return Colors.cyan.shade300;
      case NotificationEventTypes.waitingCustomerAdded:
        return Colors.purple.shade300;
      default:
        return Colors.blue.shade300;
    }
  }
}