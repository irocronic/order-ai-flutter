// lib/utils/localization_helper.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Sipariş durum anahtarını alıp yerelleştirilmiş metni döndürür.
String getLocalizedOrderStatus(BuildContext context, String? statusKey) {
  final l10n = AppLocalizations.of(context)!;

  switch (statusKey) {
    case 'pending_approval':
      return l10n.orderStatusPendingApproval;
    case 'approved':
      return l10n.orderStatusApproved;
    case 'preparing':
      return l10n.orderStatusPreparing;
    case 'ready_for_pickup':
      return l10n.orderStatusReadyForPickup;
    case 'ready_for_delivery':
      return l10n.orderStatusReadyForDelivery;
    case 'completed':
      return l10n.orderStatusCompleted;
    case 'cancelled':
      return l10n.orderStatusCancelled;
    case 'rejected':
      return l10n.orderStatusRejected;
    case 'pending_sync':
      return l10n.orderStatusPendingSync;
    default:
      return statusKey ?? l10n.unknown; // Bilinmeyen bir durum gelirse anahtarı göster
  }
}