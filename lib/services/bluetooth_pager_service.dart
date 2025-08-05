// lib/services/bluetooth_pager_service.dart
import 'dart:async';
import 'dart:convert'; // utf8 için
import 'package:flutter/foundation.dart'; // ChangeNotifier, kIsWeb ve debugPrint için
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // YENİ: Yerelleştirme importu
import '../models/pager_device_model.dart';

class BluetoothPagerService extends ChangeNotifier {
  final Guid _pagerServiceUuid = Guid("0000FEE0-0000-1000-8000-00805F9B34FB");
  final Guid _pagerCommandCharacteristicUuid = Guid("0000FEE1-0000-1000-8000-00805F9B34FB");

  // YENİ: l10n nesnesini tutmak için alan
  AppLocalizations? _l10n;

  List<PagerDevice> _discoveredPagers = [];
  List<PagerDevice> get discoveredPagers => _discoveredPagers;

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  BluetoothCharacteristic? _pagerCommandCharacteristicInternal;
  BluetoothCharacteristic? get pagerCommandCharacteristic => _pagerCommandCharacteristicInternal;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String _connectionStatus = "Bağlantı bekleniyor..."; // Varsayılan metin
  String get connectionStatus => _connectionStatus;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  bool _isDisposed = false;

  BluetoothPagerService() {
    // Başlatma işlemi artık init metodunda l10n ile birlikte yapılacak.
  }
  
  // YENİ: Servisi başlatan ve l10n nesnesini alan metot
  void init(AppLocalizations l10n) {
    _l10n = l10n;
    _connectionStatus = l10n.bleStatusNotConnected;
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    if (_l10n == null) return; // Henüz başlatılmadıysa devam etme
    final l10n = _l10n!;

    if (kIsWeb) {
      _updateConnectionStatus(l10n.bleStatusUnsupportedWeb);
      debugPrint("BluetoothPagerService: Web platformu, Bluetooth başlatma atlandı.");
      return;
    }
    if (await FlutterBluePlus.isSupported == false) {
      debugPrint("Bluetooth LE desteklenmiyor.");
      _updateConnectionStatus(l10n.bleStatusUnsupportedDevice);
      return;
    }
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (_isDisposed) return;
      debugPrint("Bluetooth Adapter State: $state");
      if (state == BluetoothAdapterState.on) {
        _updateConnectionStatus(l10n.bleStatusOn);
      } else {
        _updateConnectionStatus(l10n.bleStatusOff);
        _isConnected = false;
        _connectedDevice = null;
        _pagerCommandCharacteristicInternal = null;
        notifyListeners();
      }
    });
  }

  void _updateConnectionStatus(String status) {
    if (_isDisposed) return;
    _connectionStatus = status;
    notifyListeners();
  }

  Future<bool> _requestPermissions() async {
    if (_l10n == null) return false;
    final l10n = _l10n!;

    if (kIsWeb) {
      _updateConnectionStatus(l10n.bleStatusUnsupportedWeb);
      return true;
    }
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    if (statuses[Permission.location]!.isGranted &&
        statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted) {
      return true;
    } else {
      debugPrint("Bluetooth izinleri verilmedi.");
      _updateConnectionStatus(l10n.bleStatusPermissionsRequired);
      return false;
    }
  }

  Future<void> startScan({String? targetDeviceNameOrId, bool scanForAllServices = false}) async {
    if (_l10n == null) return;
    final l10n = _l10n!;

    if (kIsWeb) {
      _updateConnectionStatus(l10n.bleStatusUnsupportedWeb);
      _isScanning = false;
      notifyListeners();
      debugPrint("startScan çağrıldı (web), Bluetooth işlemleri atlandı.");
      return;
    }

    if (_isScanning || _isDisposed) return;
    if (!await _requestPermissions()) return;

    _discoveredPagers.clear();
    notifyListeners();

    _updateConnectionStatus(l10n.bleStatusScanning);
    _isScanning = true;
    notifyListeners();

    Set<String> foundDeviceIds = {};

    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          if (_isDisposed) return;
          for (ScanResult r in results) {
            String deviceId = r.device.remoteId.toString();
            String deviceName = r.device.platformName.isNotEmpty ? r.device.platformName : l10n.bleDeviceNameUnknown;
            
            bool matchesTargetId = targetDeviceNameOrId != null && deviceId.toLowerCase() == targetDeviceNameOrId.toLowerCase();
            bool matchesTargetName = targetDeviceNameOrId != null && deviceName.toLowerCase().contains(targetDeviceNameOrId.toLowerCase());
            bool advertisesPagerService = r.advertisementData.serviceUuids.contains(_pagerServiceUuid);

            bool shouldAddDevice = false;
            if (targetDeviceNameOrId != null) {
                if (matchesTargetId || matchesTargetName) {
                    shouldAddDevice = true;
                }
            } else { 
                if (scanForAllServices || advertisesPagerService) {
                    shouldAddDevice = true;
                }
            }

            if (shouldAddDevice && !foundDeviceIds.contains(deviceId)) {
                _discoveredPagers.add(PagerDevice(device: r.device, name: deviceName, id: deviceId));
                foundDeviceIds.add(deviceId);
                notifyListeners();
                if (matchesTargetId && targetDeviceNameOrId != null) {
                    debugPrint("Hedeflenen cihaz ID ile bulundu: $deviceId. Tarama durduruluyor.");
                    stopScan(); 
                    return; 
                }
            }
          }
        },
        onError: (e) {
          if (_isDisposed) return;
          debugPrint("Tarama sırasında hata: $e");
          stopScan();
        },
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10) 
      );
      if (!_isDisposed && _isScanning) {
          _isScanning = false;
          _updateConnectionStatus(_discoveredPagers.isEmpty ? l10n.bleStatusDeviceNotFound : l10n.bleStatusDeviceFound(_discoveredPagers.length.toString()));
          notifyListeners();
      }

    } catch (e) {
      if (!_isDisposed) {
        debugPrint("Tarama başlatılırken hata: $e");
        _updateConnectionStatus(l10n.bleStatusScanError(e.toString()));
        _isScanning = false;
        notifyListeners();
      }
    }
  }

  Future<void> stopScan() async {
    if (kIsWeb || _isDisposed || _l10n == null) return;
    final l10n = _l10n!;

    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_isScanning) {
      _isScanning = false;
      _updateConnectionStatus(_discoveredPagers.isNotEmpty ? l10n.bleStatusDeviceFound(_discoveredPagers.length.toString()) : l10n.bleStatusScanStopped);
      notifyListeners();
    }
  }

  Future<bool> connectToPagerById(String pagerId) async {
    if (kIsWeb || _isDisposed || _l10n == null) return false;
    final l10n = _l10n!;
    
    debugPrint("Pager ID '$pagerId' için bağlantı deneniyor...");

    if (_isConnected && _connectedDevice?.remoteId.toString() == pagerId) {
      debugPrint("Zaten bu çağrı cihazına (${pagerId}) bağlı.");
      if (_pagerCommandCharacteristicInternal != null) {
        return true;
      }
      return await _discoverServicesAndCharacteristics(_connectedDevice!);
    }
      if (_isConnected && _connectedDevice != null) {
        await disconnectPager();
    }
    
    PagerDevice? targetPagerFromDiscovered = _discoveredPagers.firstWhere(
      (p) => p.id == pagerId,
      orElse: () => PagerDevice(device: BluetoothDevice.fromId(pagerId), name: l10n.bleDeviceNameSearchedById, id: pagerId),
    );

    BluetoothDevice deviceToConnect;

    if (targetPagerFromDiscovered.id == pagerId && targetPagerFromDiscovered.device.platformName != l10n.bleDeviceNameSearchedById) {
        deviceToConnect = targetPagerFromDiscovered.device;
    } else {
        debugPrint("Pager ID '$pagerId' keşfedilenlerde yok. Özel tarama başlatılıyor...");
        await startScan(targetDeviceNameOrId: pagerId, scanForAllServices: true);
        
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 500));
          return _isScanning;
        });
        final foundAfterScan = _discoveredPagers.firstWhere(
            (p) => p.id == pagerId,
            orElse: () => PagerDevice(device: BluetoothDevice.fromId("00:00:00:00:00:00"), name: l10n.bleDeviceNameNotFound, id: l10n.bleDeviceNameNotFound)
        );

        if (foundAfterScan.id == l10n.bleDeviceNameNotFound) {
            _updateConnectionStatus(l10n.bleStatusDeviceNotFoundAfterScan(pagerId));
            return false;
        }
        deviceToConnect = foundAfterScan.device;
    }
    return await connectToPager(deviceToConnect);
  }

  Future<bool> connectToPager(BluetoothDevice device) async {
    if (kIsWeb || _isDisposed || _l10n == null) return false;
    final l10n = _l10n!;

    if (_isConnected && _connectedDevice?.remoteId == device.remoteId) {
      debugPrint("Zaten bu cihaza bağlı: ${device.platformName}");
      if (_pagerCommandCharacteristicInternal != null) return true;
      return await _discoverServicesAndCharacteristics(device);
    }
    if (_isScanning) await stopScan();

    _updateConnectionStatus(l10n.bleStatusConnectingTo(device.platformName));
    try {
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((BluetoothConnectionState state) async {
        if (_isDisposed) return;
        debugPrint("${device.platformName} Bağlantı Durumu: $state");
        if (state == BluetoothConnectionState.connected) {
          _isConnected = true;
          _connectedDevice = device;
          _updateConnectionStatus(l10n.bleStatusConnectedTo(device.platformName));
          await _discoverServicesAndCharacteristics(device);
        } else if (state == BluetoothConnectionState.disconnected) {
          if (_connectedDevice?.remoteId == device.remoteId) {
            _isConnected = false;
            _connectedDevice = null;
            _pagerCommandCharacteristicInternal = null;
            _updateConnectionStatus(l10n.bleStatusDisconnectedFrom(device.platformName));
          }
        }
        notifyListeners();
      });

      await device.connect(timeout: const Duration(seconds: 15));
      return _isConnected;
    } catch (e) {
      if (!_isDisposed) {
        debugPrint("${device.platformName}'e bağlanırken hata: $e");
        _updateConnectionStatus(l10n.bleStatusCouldNotConnectTo(device.platformName));
      }
      return false;
    }
  }

  Future<void> disconnectPager() async {
    if (kIsWeb || _isDisposed || _connectedDevice == null || _l10n == null) return;
    final l10n = _l10n!;

    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    try {
        await _connectedDevice!.disconnect();
    } catch (e) {
        debugPrint("Disconnect hatası: $e");
        if (!_isDisposed) {
          _isConnected = false;
          _connectedDevice = null;
          _pagerCommandCharacteristicInternal = null;
          _updateConnectionStatus(l10n.bleStatusDisconnectError);
          notifyListeners();
        }
    }
  }

  Future<bool> _discoverServicesAndCharacteristics(BluetoothDevice device) async {
    if (!_isConnected || kIsWeb || _isDisposed || _l10n == null) return false;
    final l10n = _l10n!;
    
    _updateConnectionStatus(l10n.bleStatusDiscoveringServices);
    try {
      List<BluetoothService> services = await device.discoverServices();
      if (_isDisposed) return false;
      for (BluetoothService service in services) {
        if (service.uuid == _pagerServiceUuid) {
          debugPrint("Çağrı cihazı servisi bulundu: ${service.uuid}");
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == _pagerCommandCharacteristicUuid) {
              _pagerCommandCharacteristicInternal = characteristic;
              _updateConnectionStatus(l10n.bleStatusCharacteristicFound);
              debugPrint("Çağrı cihazı komut karakteristiği bulundu: ${characteristic.uuid}");
              notifyListeners();
              return true;
            }
          }
        }
      }
      _updateConnectionStatus(l10n.bleStatusCharacteristicNotFound);
      return false;
    } catch (e) {
      if (!_isDisposed) {
        debugPrint("Servis keşfi sırasında hata: $e");
        _updateConnectionStatus(l10n.bleStatusDiscoveringServicesError);
      }
      return false;
    }
  }

  Future<bool> _sendCommand(List<int> commandBytes) async {
    if (_l10n == null) return false;
    final l10n = _l10n!;

    if (kIsWeb || !_isConnected || _pagerCommandCharacteristicInternal == null || _isDisposed) {
      debugPrint("Komut gönderilemedi: Web / Cihaz bağlı değil / Karakteristik yok.");
      if (!kIsWeb) _updateConnectionStatus(l10n.bleStatusCommandFailed);
      return false;
    }
    try {
      await _pagerCommandCharacteristicInternal!.write(commandBytes, withoutResponse: true);
      debugPrint("Komut gönderildi: $commandBytes -> ${utf8.decode(commandBytes, allowMalformed: true)}");
      _updateConnectionStatus(l10n.bleStatusCommandSent);
      return true;
    } catch (e) {
      if (!_isDisposed) {
        debugPrint("Komut gönderme hatası: $e");
        _updateConnectionStatus(l10n.bleStatusCommandError);
      }
      return false;
    }
  }

  Future<bool> sendTitle(String title) async {
    if (kIsWeb || title.isEmpty || _isDisposed) return false;
    String commandString = "TITLE:$title";
    List<int> commandBytes = utf8.encode(commandString);
    return await _sendCommand(commandBytes);
  }

  Future<bool> sendVibration({int durationMs = 500}) async {
    if (kIsWeb || _isDisposed) return false;
    String commandString = "VIBRATE:$durationMs";
    List<int> commandBytes = utf8.encode(commandString);
    return await _sendCommand(commandBytes);
  }

  Future<bool> sendFlash({int count = 3, int onMs = 200, int offMs = 200}) async {
    if (kIsWeb || _isDisposed) return false;
    String commandString = "FLASH:$count:$onMs:$offMs";
    List<int> commandBytes = utf8.encode(commandString);
    return await _sendCommand(commandBytes);
  }
  
  Future<bool> notifySpecificPagerOrderReady(String pagerDeviceId, String orderIdentifier, String customerIdentifier) async {
    if (kIsWeb || _isDisposed || _l10n == null) return false;
    final l10n = _l10n!;

    _updateConnectionStatus(l10n.bleStatusPreparingNotificationFor(pagerDeviceId));

    bool connectedAndReady = false;
    if (_isConnected && _connectedDevice?.remoteId.toString() == pagerDeviceId && _pagerCommandCharacteristicInternal != null) {
      connectedAndReady = true;
    } else {
      bool initialConnection = await connectToPagerById(pagerDeviceId);
      if (initialConnection) {
        for (int i = 0; i < 10; i++) { 
          if (_pagerCommandCharacteristicInternal != null || _isDisposed) break;
          await Future.delayed(const Duration(milliseconds: 500));
          if (_connectedDevice != null && _pagerCommandCharacteristicInternal == null && i % 4 == 0 && i > 0) { 
            await _discoverServicesAndCharacteristics(_connectedDevice!);
          }
        }
        if (_pagerCommandCharacteristicInternal != null) {
            connectedAndReady = true;
        }
      }
    }
    if (_isDisposed) return false;

    if (!connectedAndReady) {
      _updateConnectionStatus(l10n.bleStatusCouldNotConnectForNotification(pagerDeviceId));
      return false;
    }
    
    bool titleSuccess = await sendTitle("Sipariş #$orderIdentifier Hazır ($customerIdentifier)");
    await Future.delayed(const Duration(milliseconds: 100));
    bool vibrationSuccess = await sendVibration(durationMs: 1000);
    await Future.delayed(const Duration(milliseconds: 100));
    bool flashSuccess = await sendFlash(count: 3, onMs: 300, offMs: 300);

    if (titleSuccess && vibrationSuccess && flashSuccess) {
      _updateConnectionStatus(l10n.bleStatusNotificationSent(pagerDeviceId));
      return true;
    } else {
      _updateConnectionStatus(l10n.bleStatusNotificationError(pagerDeviceId));
      return false;
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint("BluetoothPagerService dispose ediliyor.");
    _scanSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    if (!kIsWeb && (_connectedDevice?.isConnected ?? false) ) {
        _connectedDevice?.disconnect().catchError((e) {
            debugPrint("Dispose sırasında disconnect hatası: $e");
        });
    }
    super.dispose();
  }
}