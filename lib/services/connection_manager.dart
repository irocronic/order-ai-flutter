// lib/services/connection_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'socket_service.dart';
import 'user_session.dart';

class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  Timer? _connectionCheckTimer;
  bool _isMonitoring = false;
  bool _isCheckingConnection = false;
  DateTime? _lastConnectionCheck;

  void startMonitoring() {
    if (_isMonitoring) return;

    // If there's no token, don't start monitoring.
    if (UserSession.token.isEmpty) {
      print('[ConnectionManager] startMonitoring çağrıldı ancak token bulunamadı - izleme başlatılmıyor.');
      return;
    }

    // Also ensure socket initialization is allowed (prevents starting monitor while logout in progress)
    if (!SocketService.initializationAllowed) {
      print('[ConnectionManager] startMonitoring çağrıldı ancak SocketService initialization engellenmiş - izleme başlatılmıyor.');
      return;
    }

    print('[ConnectionManager] Bağlantı izleme başlatılıyor...');
    _isMonitoring = true;
    _connectionCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkConnections();
    });
  }

  void _checkConnections() {
    if (_isCheckingConnection) return;

    _isCheckingConnection = true;

    try {
      _lastConnectionCheck = DateTime.now();
      final socketService = SocketService.instance;

      // If token is empty at check time, stop monitoring to avoid repeated connect attempts.
      if (UserSession.token.isEmpty) {
        print('[ConnectionManager] _checkConnections: token yok - izleme durduruluyor.');
        stopMonitoring();
        _isCheckingConnection = false;
        return;
      }

      // If initialization currently not allowed then stop monitoring as well
      if (!SocketService.initializationAllowed) {
        print('[ConnectionManager] _checkConnections: SocketService initialization blocked - izleme durduruluyor.');
        stopMonitoring();
        _isCheckingConnection = false;
        return;
      }

      final isActuallyConnected = socketService.checkConnection();

      if (!isActuallyConnected) {
        if (socketService.isConnecting) {
          print('⚠️ [ConnectionManager] Socket halen bağlanıyor, yeni deneme atlanıyor.');
        } else {
          print('⚠️ [ConnectionManager] Socket bağlantısı kopuk, yeniden bağlanılıyor...');

          if (UserSession.token.isNotEmpty) {
            socketService.connectAndListen();
          } else {
            print('❌ [ConnectionManager] Token bulunamadı, yeniden bağlanma iptal edildi');
          }
        }
      } else {
        if (kDebugMode) {
          print('✅ [ConnectionManager] Bağlantılar normal');
        }
      }
    } catch (e) {
      print('❌ [ConnectionManager] Bağlantı kontrolü hatası: $e');
    } finally {
      _isCheckingConnection = false;
    }
  }

  void forceReconnect() {
    print('[ConnectionManager] Zorla yeniden bağlanma tetiklendi');
    _checkConnections();
  }

  void stopMonitoring() {
    print('[ConnectionManager] Bağlantı izleme durduruluyor...');
    _isMonitoring = false;
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
  }

  bool get isMonitoring => _isMonitoring;
  DateTime? get lastConnectionCheck => _lastConnectionCheck;
}