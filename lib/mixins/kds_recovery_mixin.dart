// lib/mixins/kds_recovery_mixin.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/socket_service.dart';
import '../services/refresh_manager.dart';
import '../main.dart';
import '../utils/notifiers.dart';

mixin KdsRecoveryMixin<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  // Recovery timer properties
  Timer? immediateRecoveryTimer;
  Timer? shortDelayRecoveryTimer;
  Timer? mediumDelayRecoveryTimer;
  Timer? forceRecoveryTimer;
  Timer? roomStabilityTimer;
  bool recoveryInProgress = false;
  
  // App resume tracking
  DateTime? lastBackgroundTime;
  DateTime? lastRoomJoinTime;
  bool needsDataRefreshOnResume = false;
  bool roomConnectionStable = false;
  int roomJoinAttempts = 0;
  bool isAppInForeground = true;
  bool isJoinedToRoom = false;
  
  // Required getters - must be implemented by the using class
  String get kdsScreenSlug;
  SocketService get socketService;
  bool get isDisposed;
  bool get isCurrent;
  DateTime? get lastRefreshTime;
  set lastRefreshTime(DateTime? value);
  
  // Required methods - must be implemented by the using class
  Future<void> fetchKdsOrders();
  void leaveKdsRoom();
  void emergencyStopAllOperations();
  void processPendingNotifications();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isDisposed) return;
    
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        lastBackgroundTime = DateTime.now();
        needsDataRefreshOnResume = true;
        roomConnectionStable = false;
        debugPrint('[KdsScreen-$kdsScreenSlug] ⏸️ App paused at $lastBackgroundTime');
        
        // Smart delayed emergency stop - filter fast transitions
        Timer(const Duration(milliseconds: 800), () {
          if (!mounted || isDisposed) return;
          if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
            emergencyStopAllOperations();
            debugPrint('[KdsScreen-$kdsScreenSlug] 🛑 Emergency stop executed after delay');
          }
        });
        break;
        
      case AppLifecycleState.resumed:
        isAppInForeground = true;
        debugPrint('[KdsScreen-$kdsScreenSlug] ▶️ App resumed - smart recovery starting');
        
        // Smart recovery with multiple strategies
        smartMultiRecovery();
        break;
        
      case AppLifecycleState.hidden:
        lastBackgroundTime = DateTime.now();
        needsDataRefreshOnResume = true;
        debugPrint('[KdsScreen-$kdsScreenSlug] 👁️ App hidden - light mode');
        break;
      case AppLifecycleState.inactive:
        debugPrint('[KdsScreen-$kdsScreenSlug] 💤 App inactive - ignored');
        break;
        
      default:
        break;
    }
  }

  // Smart Multi Recovery System
  void smartMultiRecovery() {
    if (isDisposed || !mounted || recoveryInProgress) return;
    
    recoveryInProgress = true;
    cancelAllRecoveryTimers();
    
    // Background duration analysis
    final backgroundDuration = lastBackgroundTime != null 
        ? DateTime.now().difference(lastBackgroundTime!) 
        : Duration.zero;
        
    final isLongBackground = backgroundDuration.inSeconds > 30;
    final isShortBackground = backgroundDuration.inSeconds < 2;
    
    debugPrint('[KdsScreen-$kdsScreenSlug] 🧠 Smart Multi Recovery - Background: ${backgroundDuration.inSeconds}s');
    
    if (isShortBackground) {
      // Fast transition - only immediate recovery
      debugPrint('[KdsScreen-$kdsScreenSlug] ⚡ Fast transition detected - minimal recovery');
      immediateRecoveryTimer = Timer(const Duration(milliseconds: 50), () {
        attemptRecovery('fast_transition');
        recoveryInProgress = false;
      });
      return;
    }
    
    // Strategy 1: Immediate attempt (100ms delay)
    immediateRecoveryTimer = Timer(const Duration(milliseconds: 100), () {
      if (!isDisposed && mounted && isCurrent) {
        if (attemptRecovery('immediate')) {
          debugPrint('[KdsScreen-$kdsScreenSlug] ✅ Immediate recovery successful');
          recoveryInProgress = false;
          return;
        }
      }
    });
    
    // Strategy 2: Short delay (500ms)
    shortDelayRecoveryTimer = Timer(const Duration(milliseconds: 500), () {
      if (!isDisposed && mounted && isCurrent && recoveryInProgress) {
        if (attemptRecovery('short_delay')) {
          debugPrint('[KdsScreen-$kdsScreenSlug] ✅ Short delay recovery successful');
          recoveryInProgress = false;
          return;
        }
      }
    });
    
    // Strategy 3: Medium delay (1.5s) - for longer backgrounds
    if (isLongBackground) {
      mediumDelayRecoveryTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!isDisposed && mounted && isCurrent && recoveryInProgress) {
          if (attemptRecovery('medium_delay_refresh')) {
            debugPrint('[KdsScreen-$kdsScreenSlug] ✅ Medium delay recovery with refresh successful');
            recoveryInProgress = false;
            return;
          }
        }
      });
    }
    
    // Strategy 4: Force recovery (3s) - ignore locks
    forceRecoveryTimer = Timer(const Duration(seconds: 3), () {
      if (!isDisposed && mounted && isCurrent && recoveryInProgress) {
        debugPrint('[KdsScreen-$kdsScreenSlug] 🔥 Force recovery attempt - bypassing locks');
        forceRecovery();
        recoveryInProgress = false;
      }
    });
  }

  // Attempt recovery with different strategies
  bool attemptRecovery(String strategy) {
    // Lifecycle check
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      debugPrint('[KdsScreen-$kdsScreenSlug] Recovery blocked - not resumed ($strategy)');
      return false;
    }
    
    // Navigator check (relaxed for immediate/fast strategies)
    final bypassLocks = strategy.contains('immediate') || strategy.contains('fast');
    if (!bypassLocks && (NavigatorSafeZone.isBusy || BuildLockManager.isLocked)) {
      debugPrint('[KdsScreen-$kdsScreenSlug] Recovery blocked - Navigator/Build busy ($strategy)');
      return false;
    }
    
    try {
      debugPrint('[KdsScreen-$kdsScreenSlug] 🔄 Recovery ($strategy) starting...');
      
      // Smart room join with stability
      joinKdsRoomWithStability();
      
      // Smart data refresh based on strategy
      if (strategy.contains('refresh') || strategy.contains('medium') || needsDataRefreshOnResume) {
        debugPrint('[KdsScreen-$kdsScreenSlug] 🔄 Force refreshing stale data');
        forceFreshDataRefresh();
      } else if (!strategy.contains('fast')) {
        safeRefreshDataWithThrottling();
      }
      
      // Process pending notifications with strategy-based delay
      final delay = strategy.contains('immediate') || strategy.contains('fast') 
          ? const Duration(milliseconds: 100) 
          : const Duration(milliseconds: 400);
          
      Timer(delay, () {
        if (!isDisposed && mounted) {
          processPendingNotifications();
        }
      });
      
      needsDataRefreshOnResume = false;
      
      return true;
    } catch (e) {
      debugPrint('[KdsScreen-$kdsScreenSlug] Recovery ($strategy) failed: $e');
      return false;
    }
  }

  // Force recovery - ignore all locks
  void forceRecovery() {
    try {
      debugPrint('[KdsScreen-$kdsScreenSlug] 🔥 FORCE recovery - ignoring all locks and constraints');
      
      // Force free all locks
      NavigatorSafeZone.markFree('emergency_stop');
      NavigatorSafeZone.markFree('force_recovery');
      BuildLockManager.unlockBuild('force_recovery');
      
      // Force room join
      forceJoinKdsRoom();
      
      // Force data refresh
      forceFreshDataRefresh();
      
      Timer(const Duration(milliseconds: 300), () {
        if (!isDisposed && mounted) {
          processPendingNotifications();
        }
      });
      
      needsDataRefreshOnResume = false;
      
    } catch (e) {
      debugPrint('[KdsScreen-$kdsScreenSlug] Force recovery failed: $e');
    }
  }

  // Smart Room Join with Stability
  void joinKdsRoomWithStability() {
    if (!isCurrent || isDisposed || !mounted) return;
    
    // Prevent rapid join/leave cycles
    final now = DateTime.now();
    if (lastRoomJoinTime != null && now.difference(lastRoomJoinTime!).inMilliseconds < 1000) {
      debugPrint('[KdsScreen-$kdsScreenSlug] 🚫 Room join throttled - too frequent');
      return;
    }
    
    lastRoomJoinTime = now;
    roomJoinAttempts++;
    
    if (!socketService.isConnected) {
      debugPrint('[KdsScreen-$kdsScreenSlug] 🚫 Socket not connected, scheduling retry');
      // Retry after socket connects
      Timer(const Duration(seconds: 2), () {
        if (!isDisposed && mounted && socketService.isConnected) {
          joinKdsRoomWithStability();
        }
      });
      return;
    }
    
    try {
      socketService.joinKdsRoom(kdsScreenSlug);
      isJoinedToRoom = true;
      debugPrint('[KdsScreen-$kdsScreenSlug] ✅ Joined KDS room (attempt: $roomJoinAttempts)');
      
      // Mark as stable after successful join
      roomStabilityTimer?.cancel();
      roomStabilityTimer = Timer(const Duration(seconds: 3), () {
        roomConnectionStable = true;
        debugPrint('[KdsScreen-$kdsScreenSlug] 🟢 Room connection marked as stable');
      });
      
    } catch (e) {
      debugPrint('[KdsScreen-$kdsScreenSlug] ❌ Room join failed: $e');
      isJoinedToRoom = false;
    }
  }

  // Force Room Join (bypasses all checks)
  void forceJoinKdsRoom() {
    try {
      if (socketService.isConnected) {
        socketService.joinKdsRoom(kdsScreenSlug);
        isJoinedToRoom = true;
        roomConnectionStable = true;
        debugPrint('[KdsScreen-$kdsScreenSlug] 🔥 FORCE joined KDS room');
      }
    } catch (e) {
      debugPrint('[KdsScreen-$kdsScreenSlug] Force room join failed: $e');
    }
  }

  // Force data refresh
  void forceFreshDataRefresh() {
    if (isDisposed || !mounted) return;
    
    // Bypass throttling
    lastRefreshTime = null;
    
    debugPrint('[KdsScreen-$kdsScreenSlug] 💪 Force fresh data refresh');
    fetchKdsOrders();
  }

  // Throttled refresh using RefreshManager
  void safeRefreshDataWithThrottling() {
    if (isDisposed || !mounted) return;
    
    final refreshKey = 'kds_screen_$kdsScreenSlug';
    RefreshManager.throttledRefresh(refreshKey, () async {
      await fetchKdsOrders();
    });
  }

  // Cancel all recovery timers
  void cancelAllRecoveryTimers() {
    immediateRecoveryTimer?.cancel();
    shortDelayRecoveryTimer?.cancel();
    mediumDelayRecoveryTimer?.cancel();
    forceRecoveryTimer?.cancel();
  }

  // Cleanup method to be called in dispose
  void disposeRecoveryMixin() {
    cancelAllRecoveryTimers();
    roomStabilityTimer?.cancel();
    leaveKdsRoom();
  }
}