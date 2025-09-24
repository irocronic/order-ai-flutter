// lib/services/shift_manager.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/scheduled_shift_model.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';

class ShiftManager {
  static final ShiftManager _instance = ShiftManager._internal();
  static ShiftManager get instance => _instance;
  ShiftManager._internal();

  Timer? _shiftEndTimer;
  String? _shiftCountdownText;
  ScheduledShift? _activeShift;
  final ValueNotifier<String?> shiftCountdownNotifier = ValueNotifier(null);

  String? get shiftCountdownText => _shiftCountdownText;
  ScheduledShift? get activeShift => _activeShift;

  void dispose() {
    _shiftEndTimer?.cancel();
    shiftCountdownNotifier.dispose();
  }

  Future<void> fetchAndMonitorShift(String token, VoidCallback onShiftEnd) async {
    final userType = UserSession.userType;

    if (userType == 'staff' || userType == 'kitchen_staff') {
      debugPrint("[ShiftManager] Personel kullanıcısı, aktif vardiya bilgisi çekiliyor...");
      try {
        final shiftData = await ApiService.fetchCurrentShift(token);
        _activeShift = ScheduledShift.fromJson(shiftData);
        _startShiftEndTimer(onShiftEnd);
      } catch (e) {
        debugPrint("[ShiftManager] Aktif vardiya bilgisi alınamadı veya şu an aktif vardiya yok: $e");
        _activeShift = null;
        _shiftCountdownText = null;
        shiftCountdownNotifier.value = null;
      }
    }
  }

  void _startShiftEndTimer(VoidCallback onShiftEnd) {
    _shiftEndTimer?.cancel();
    if (_activeShift == null) return;

    final String? endTimeUtcString = _activeShift!.endDateTimeUtc;
    if (endTimeUtcString == null) return;

    final shiftEndTime = DateTime.parse(endTimeUtcString);

    _shiftEndTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().toUtc();
      final durationUntilEnd = shiftEndTime.difference(now);

      if (durationUntilEnd.isNegative) {
        _shiftCountdownText = "Vardiya Bitti"; // Bu localization'a taşınacak
        shiftCountdownNotifier.value = _shiftCountdownText;
        timer.cancel();
        onShiftEnd();
        return;
      }

      if (durationUntilEnd.inMinutes < 5) {
        final minutes = durationUntilEnd.inMinutes;
        final seconds = durationUntilEnd.inSeconds % 60;
        _shiftCountdownText = "Vardiya Bitiyor: ${minutes}:${seconds.toString().padLeft(2, '0')}";
        shiftCountdownNotifier.value = _shiftCountdownText;
      } else {
        if (_shiftCountdownText != null) {
          _shiftCountdownText = null;
          shiftCountdownNotifier.value = null;
        }
      }
    });
  }

  Widget buildShiftTimerWidget(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (_activeShift == null || (UserSession.userType != 'staff' && UserSession.userType != 'kitchen_staff')) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<String?>(
      valueListenable: shiftCountdownNotifier,
      builder: (context, countdownText, child) {
        if (countdownText != null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  countdownText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                '${l10n.shiftLabel}: ${_activeShift!.shift.startTime.format(context)} - ${_activeShift!.shift.endTime.format(context)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  void showShiftEndDialog(BuildContext context, VoidCallback onLogout) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.shiftEndedDialogTitle),
        content: Text(l10n.shiftEndedDialogContent),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onLogout();
            },
            child: Text(l10n.logoutButtonText),
          ),
        ],
      ),
    );
  }
}