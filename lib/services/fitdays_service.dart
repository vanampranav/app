import 'dart:async';
import 'package:flutter/services.dart';
import '../models/device_model.dart';

/// Service for communicating with FitDays SDK via platform channels
/// Handles device scanning, connection, and data reception
class FitDaysService {
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

  // Public streams
  Stream<FitDaysDevice> get deviceFoundStream => _deviceFoundController.stream;
  Stream<Map<String, dynamic>> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<WeightMeasurement> get weightDataStream =>
      _weightDataController.stream;
  Stream<bool> get scanningStream => _scanningController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool _isInitialized = false;
  bool _isScanning = false;
  StreamSubscription? _eventSubscription;

  FitDaysService() {
    _setupEventListener();
  }

  /// Set up event channel listener for SDK events
  void _setupEventListener() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _handleEvent(Map<String, dynamic>.from(event));
        }
      },
      onError: (error) {
        print('FitDays Event Channel Error: $error');
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

    print('FitDays Event: $type, Data: $data');

    switch (type) {
      case 'deviceFound':
        if (data != null) {
          final device = FitDaysDevice.fromMap(data);
          _deviceFoundController.add(device);
        }
        break;

      case 'connectionStateChanged':
        if (data != null) {
          _connectionStateController.add(data);
        }
        break;

      case 'weightData':
      // Safety fallback: iOS used to send kitchen scale readings as 'kitchenScaleData'
      // (now fixed in Swift to send 'weightData'). Keep this case to stay resilient.
      case 'kitchenScaleData':
        if (data != null) {
          final measurement = WeightMeasurement.fromMap(data);
          _weightDataController.add(measurement);
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
        print('SDK Initialized: $_isInitialized');
        break;

      case 'bluetoothStateChanged':
        print('Bluetooth State: ${data?['state']}');
        break;

      case 'error':
        final message = data?['message'] as String? ?? 'Unknown error';
        _errorController.add(message);
        break;

      default:
        print('Unknown event type: $type');
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
      print('Error initializing SDK: $e');
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
      print('Error checking permissions: $e');
      return false;
    }
  }

  /// Request Bluetooth permissions
  Future<bool> requestPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod('requestPermissions');
      return result == true;
    } catch (e) {
      print('Error requesting permissions: $e');
      _errorController.add('Failed to request permissions: $e');
      return false;
    }
  }

  /// Start scanning for nearby FitDays devices
  Future<void> startScan() async {
    try {
      await _methodChannel.invokeMethod('startScan');
    } on PlatformException catch (e) {
      print('Error starting scan: ${e.message}');
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
      print('Error stopping scan: $e');
    }
  }

  /// Connect to a device by MAC address
  Future<void> connectDevice(String macAddress) async {
    try {
      await _methodChannel.invokeMethod('connectDevice', {
        'macAddress': macAddress,
      });
    } catch (e) {
      print('Error connecting to device: $e');
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
      print('Error disconnecting device: $e');
      _errorController.add('Failed to disconnect: $e');
    }
  }

  /// Get SDK version
  Future<String> getSDKVersion() async {
    try {
      final version = await _methodChannel.invokeMethod('getSDKVersion');
      return version as String? ?? 'Unknown';
    } catch (e) {
      print('Error getting SDK version: $e');
      return 'Unknown';
    }
  }

  /// Send Tare command to kitchen scale
  Future<bool> sendTareCommand(String deviceId) async {
    try {
      print('Sending tare command to device: $deviceId');
      final result = await _methodChannel.invokeMethod('sendTareCommand', {
        'deviceId': deviceId,
      });
      print('Tare command result: $result');
      return result == true;
    } catch (e) {
      print('Error sending tare command: $e');
      _errorController.add(e.toString());
      return false;
    }
  }

  /// Send Unit change command to kitchen scale
  Future<bool> sendUnitChangeCommand(String deviceId, String unit) async {
    try {
      print('Sending unit change command to device: $deviceId, unit: $unit');
      final result = await _methodChannel.invokeMethod('sendUnitChangeCommand', {
        'deviceId': deviceId,
        'unit': unit,
      });
      print('Unit change command result: $result');
      return result == true;
    } catch (e) {
      print('Error sending unit change command: $e');
      _errorController.add(e.toString());
      return false;
    }
  }

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  /// Check if SDK is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose of resources
  void dispose() {
    _eventSubscription?.cancel();
    _deviceFoundController.close();
    _connectionStateController.close();
    _weightDataController.close();
    _scanningController.close();
    _errorController.close();
  }
}
