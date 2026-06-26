import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/device_model.dart';

/// Service for communicating with FitDays SDK via platform channels
/// Handles device scanning, connection, and data reception.
///
/// Singleton — every screen that calls `FitDaysService()` gets the same
/// instance, so a connection made in DevicesScreen is immediately visible
/// in NutritionLogScreen, KitchenScaleScreen, etc.
class FitDaysService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final FitDaysService _instance = FitDaysService._internal();
  factory FitDaysService() => _instance;
  FitDaysService._internal() {
    _setupEventListener();
  }

  static const MethodChannel _methodChannel =
      MethodChannel('com.theelefit.app/fitdays');
  static const EventChannel _eventChannel =
      EventChannel('com.theelefit.app/fitdays_events');

  MethodChannel get methodChannel => _methodChannel;

  // Stream controllers for reactive updates
  final _deviceFoundController = StreamController<FitDaysDevice>.broadcast();
  final _connectionStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _weightDataController = StreamController<WeightMeasurement>.broadcast();
  final _scanningController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _bluetoothStateController = StreamController<bool>.broadcast();

  // Public streams
  Stream<FitDaysDevice> get deviceFoundStream => _deviceFoundController.stream;
  Stream<Map<String, dynamic>> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<WeightMeasurement> get weightDataStream =>
      _weightDataController.stream;
  Stream<bool> get scanningStream => _scanningController.stream;

  // Last weight reading received this session. A broadcast stream only delivers
  // events that occur AFTER a listener subscribes, so a screen opened while the
  // scale is idle would otherwise see nothing. Callers seed from this on open.
  WeightMeasurement? _lastWeight;
  WeightMeasurement? get lastWeight => _lastWeight;

  // MAC of the device actively streaming weight. More reliable than
  // connectedDeviceMac for sending tare/unit commands, because a stale bound
  // device churning connect/disconnect can clobber connectedDeviceMac.
  String? _activeScaleMac;
  String? get activeScaleMac => _activeScaleMac;
  Stream<String> get errorStream => _errorController.stream;
  // Emits true when BT is powered on, false when off/unavailable
  Stream<bool> get bluetoothStateStream => _bluetoothStateController.stream;

  bool    _isInitialized    = false;
  bool    _isScanning       = false;
  bool?   _isBluetoothOn;
  bool?   get isBluetoothOn => _isBluetoothOn;
  String? _connectedDeviceMac;
  /// MAC address of the currently connected device, or null if disconnected.
  String? get connectedDeviceMac => _connectedDeviceMac;
  StreamSubscription? _eventSubscription;

  /// Set up event channel listener for SDK events
  void _setupEventListener() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _handleEvent(Map<String, dynamic>.from(event));
        }
      },
      onError: (error) {
        debugPrint('FitDays Event Channel Error: $error');
        _errorController.add(error.toString());
      },
    );
  }

  /// Handle events from native platform (Android & iOS)
  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    // Properly cast the data from Object? to Map<String, dynamic>?
    final data = event['data'] != null 
        ? Map<String, dynamic>.from(event['data'] as Map)
        : null;

    debugPrint('FitDays Event: $type, Data: $data');

    switch (type) {
      case 'deviceFound':
        if (data != null) {
          final device = FitDaysDevice.fromMap(data);
          _deviceFoundController.add(device);
        }
        break;

      case 'connectionStateChanged':
        if (data != null) {
          // Track which device is currently connected so other screens
          // (e.g. FoodDetailModal) can send tare/unit commands without
          // needing to know the MAC address themselves.
          final state = data['state'] as String?;
          final mac   = data['macAddress'] as String?;
          if (state == 'connected')    _connectedDeviceMac = mac;
          if (state == 'disconnected') _connectedDeviceMac = null;
          _connectionStateController.add(data);
        }
        break;

      case 'kitchenScaleData':
        // Android: FitDaysSDKManager.onReceiveKitchenScaleData sends this.
        // iOS fallback: older iOS SDK also used this event type for kitchen scales.
        // Either way: definitively a kitchen scale.
        if (data != null) {
          final m = WeightMeasurement.fromMap(data, source: WeightSource.kitchenScale);
          _lastWeight = m;
          if (data['macAddress'] != null) _activeScaleMac = data['macAddress'] as String?;
          _weightDataController.add(m);
        }
        break;

      case 'weightData':
        // Android: FitDaysSDKManager.onReceiveWeightData sends this.
        //          Definitively a body fat scale — no kitchen scale can reach here
        //          now that FitDaysSDKManager sends kitchenScaleData for kitchen.
        // iOS:     Both device types share this event type (unified by the Swift SDK).
        //          Use unit + weight as a fallback discriminator for iOS:
        //            g / oz / ml unit  → kitchen scale
        //            hasBodyComposition → body fat scale (definitive)
        //            weight < 10 kg    → kitchen scale  (food portion)
        //            weight ≥ 10 kg    → body fat scale (human body weight)
        if (data != null) {
          final raw = WeightMeasurement.fromMap(data);
          final WeightSource src;

          if (raw.hasBodyComposition) {
            src = WeightSource.bodyFatScale;
          } else if (raw.unit == 'g'  || raw.unit == 'oz'   ||
                     raw.unit == 'ml' || raw.unit == 'fl_oz' ||
                     raw.unit == 'mg') {
            src = WeightSource.kitchenScale;
          } else if (raw.weight < 10.0) {
            src = WeightSource.kitchenScale;
          } else {
            src = WeightSource.bodyFatScale;
          }

          final m = WeightMeasurement.fromMap(data, source: src);
          _lastWeight = m;
          if (data['macAddress'] != null) _activeScaleMac = data['macAddress'] as String?;
          _weightDataController.add(m);
        }
        break;

      case 'scanStarted':
        _isScanning = true;
        _scanningController.add(true);
        break;

      case 'scanStopped':
        _isScanning = false;
        _scanningController.add(false);
        break;

      case 'sdkInitialized':
        _isInitialized = data?['success'] == true;
        debugPrint('SDK Initialized: $_isInitialized');
        break;

      case 'bluetoothStateChanged':
        final stateVal = data?['state'];
        // iOS sends int raw value (ICBleStatePoweredOn = 4).
        // Android sends enum.toString() — exact string is SDK-internal, but "PoweredOn" appears
        // in the constant name on both platforms. Treat anything not clearly "on" as off.
        bool isOn = false;
        if (stateVal is int) {
          isOn = stateVal == 4;
        } else if (stateVal is String) {
          isOn = stateVal.toLowerCase().contains('poweredon');
        }
        _isBluetoothOn = isOn;
        _bluetoothStateController.add(isOn);
        debugPrint('Bluetooth State: $stateVal -> ${isOn ? "ON" : "OFF"}');
        break;

      case 'error':
        final message = data?['message'] as String? ?? 'Unknown error';
        _errorController.add(message);
        break;

      default:
        debugPrint('Unknown event type: $type');
    }
  }

  /// Initialize the FitDays SDK with user profile
  Future<bool> initializeSDK({
    required int age,
    required int height,
    required String sex,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('initializeSDK', {
        'age': age,
        'height': height,
        'sex': sex,
      });
      _isInitialized = result == true;
      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing SDK: $e');
      _errorController.add('Failed to initialize SDK: $e');
      return false;
    }
  }

  /// Check if Bluetooth permissions are granted
  Future<bool> checkPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod('checkPermissions');
      return result == true;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }

  /// Request Bluetooth permissions
  Future<bool> requestPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod('requestPermissions');
      return result == true;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      _errorController.add('Failed to request permissions: $e');
      return false;
    }
  }


  /// Start scanning for nearby FitDays devices
  Future<void> startScan() async {
    try {
      await _methodChannel.invokeMethod('startScan');
    } on PlatformException catch (e) {
      debugPrint('Error starting scan: ${e.message}');
      _errorController.add(e.message ?? 'Failed to start scan');
      _isScanning = false;
      _scanningController.add(false);
    }
  }

  /// Stop scanning for devices
  Future<void> stopScan() async {
    try {
      await _methodChannel.invokeMethod('stopScan');
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }
  }

  /// Connect to a device by MAC address
  Future<void> connectDevice(String macAddress) async {
    try {
      await _methodChannel.invokeMethod('connectDevice', {
        'macAddress': macAddress,
      });
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      _errorController.add('Failed to connect: $e');
    }
  }

  /// Disconnect from a device
  Future<void> disconnectDevice(String macAddress) async {
    try {
      await _methodChannel.invokeMethod('disconnectDevice', {
        'macAddress': macAddress,
      });
    } catch (e) {
      debugPrint('Error disconnecting device: $e');
      _errorController.add('Failed to disconnect: $e');
    }
  }

  /// Get SDK version
  Future<String> getSDKVersion() async {
    try {
      final version = await _methodChannel.invokeMethod('getSDKVersion');
      return version as String? ?? 'Unknown';
    } catch (e) {
      debugPrint('Error getting SDK version: $e');
      return 'Unknown';
    }
  }

  /// Send Tare command to kitchen scale
  Future<bool> sendTareCommand(String deviceId) async {
    try {
      debugPrint('Sending tare command to device: $deviceId');
      final result = await _methodChannel.invokeMethod('sendTareCommand', {
        'deviceId': deviceId,
      });
      debugPrint('Tare command result: $result');
      return result == true;
    } catch (e) {
      debugPrint('Error sending tare command: $e');
      _errorController.add(e.toString());
      return false;
    }
  }

  /// Send Unit change command to kitchen scale
  Future<bool> sendUnitChangeCommand(String deviceId, String unit) async {
    try {
      debugPrint('Sending unit change command to device: $deviceId, unit: $unit');
      final result = await _methodChannel.invokeMethod('sendUnitChangeCommand', {
        'deviceId': deviceId,
        'unit': unit,
      });
      debugPrint('Unit change command result: $result');
      return result == true;
    } catch (e) {
      debugPrint('Error sending unit change command: $e');
      _errorController.add(e.toString());
      return false;
    }
  }

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  /// Check if SDK is initialized
  bool get isInitialized => _isInitialized;

  /// No-op on the singleton — streams must stay open for the app's lifetime
  /// so that any screen can subscribe at any time after a device connects.
  /// The native SDK cleans up when the process exits.
  void dispose() {
    // intentionally empty — do not close stream controllers or cancel the
    // EventChannel subscription; doing so would break all other screens.
  }
}
