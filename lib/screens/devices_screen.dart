import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/fitdays_service.dart';
import '../services/member_service.dart';
import '../models/device_model.dart';
import '../models/member_model.dart';
import '../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'measurement_screen.dart';
import 'kitchen_scale_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  late FitDaysService _fitDaysService;
  final List<FitDaysDevice> _discoveredDevices = [];
  final List<String> _debugLogs = [];
  
  // The devices the user has "bound" (saved) to this app
  final List<FitDaysDevice> _boundDevices = [];
  
  // The currently active connection (could be one of the bound devices)
  FitDaysDevice? _connectedDevice;

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _debugLogs.add('${DateTime.now().second}:${DateTime.now().millisecond} - $message');
      if (_debugLogs.length > 50) _debugLogs.removeAt(0);
    });
  }
  WeightMeasurement? _latestMeasurement;
  bool _isScanning = false;
  bool _hasPermissions = false;
  bool? _isBluetoothOn;
  bool _bluetoothDialogShown = false;
  String? _errorMessage;
  StreamSubscription? _deviceFoundSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _weightDataSub;
  StreamSubscription? _scanningSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _bluetoothSub;

  @override
  void initState() {
    super.initState();
    _fitDaysService = FitDaysService();
    _setupListeners();
    _checkPermissionsAndInitialize();
  }

  void _setupListeners() {
    _deviceFoundSub = _fitDaysService.deviceFoundStream.listen((device) {
      _addLog('Device: ${device.macAddress}');
      debugPrint('Device found: ${device.macAddress}');
      setState(() {
        if (!_discoveredDevices.any((d) => d.macAddress == device.macAddress)) {
          _discoveredDevices.add(device);
        }
      });
    });

    _connectionSub = _fitDaysService.connectionStateStream.listen((data) {
      final macAddress = data['macAddress'] as String;
      final state = data['state'] as String;
      _addLog('Conn: $macAddress -> $state');
      debugPrint('Connection state changed: $macAddress -> $state');

      // Capture the device to navigate to outside of setState
      FitDaysDevice? deviceToNavigate;

      setState(() {
        final deviceIndex = _discoveredDevices
            .indexWhere((d) => d.macAddress == macAddress);

        if (deviceIndex != -1) {
          DeviceConnectionState connectionState;
          switch (state) {
            case 'connected':
              connectionState = DeviceConnectionState.connected;
              _connectedDevice = _discoveredDevices[deviceIndex];
              deviceToNavigate = _connectedDevice;
              break;
            case 'connecting':
              connectionState = DeviceConnectionState.connecting;
              break;
            default:
              connectionState = DeviceConnectionState.disconnected;
              if (_connectedDevice?.macAddress == macAddress) {
                _connectedDevice = null;
              }
          }
          _discoveredDevices[deviceIndex] = _discoveredDevices[deviceIndex]
              .copyWith(connectionState: connectionState);
        }

        final boundDeviceIndex =
            _boundDevices.indexWhere((d) => d.macAddress == macAddress);
        if (boundDeviceIndex != -1) {
          switch (state) {
            case 'connected':
              _connectedDevice = _boundDevices[boundDeviceIndex];
              deviceToNavigate = _connectedDevice;
              break;
            case 'disconnected':
              _connectedDevice = null;
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted &&
                    _boundDevices.isNotEmpty &&
                    _connectedDevice == null) {
                  _connectDevice(_boundDevices[boundDeviceIndex]);
                }
              });
              break;
          }
        }
      });

      // Navigate after setState so we're not calling Navigator inside a build
      if (deviceToNavigate != null && mounted) {
        if (deviceToNavigate!.deviceType == DeviceType.kitchenScale) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => KitchenScaleScreen(
                connectedDevice: deviceToNavigate!,
                fitDaysService: _fitDaysService,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MeasurementScreen(
                connectedDevice: deviceToNavigate!,
                fitDaysService: _fitDaysService,
              ),
            ),
          );
        }
      }
    });

    _weightDataSub = _fitDaysService.weightDataStream.listen((measurement) async {
      _addLog('Weight: ${measurement.weight} ${measurement.unit}');
      debugPrint('Weight data received: ${measurement.weight} ${measurement.unit}, Stabilized: ${measurement.isStabilized}');

      setState(() {
        _latestMeasurement = measurement;
      });

      if (measurement.isStabilized) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('last_measurement', jsonEncode(measurement.toMap()));
      }
    });

    _scanningSub = _fitDaysService.scanningStream.listen((isScanning) {
      _addLog('Scanning: $isScanning');
      debugPrint('Scanning state: $isScanning');
      setState(() {
        _isScanning = isScanning;
      });
    });

    _errorSub = _fitDaysService.errorStream.listen((error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
    });

    _bluetoothSub = _fitDaysService.bluetoothStateStream.listen((isOn) {
      if (!mounted) return;
      setState(() => _isBluetoothOn = isOn);
      if (!isOn && !_bluetoothDialogShown) {
        _bluetoothDialogShown = true;
        _showBluetoothOffSheet();
      } else if (isOn) {
        _bluetoothDialogShown = false;
        // Re-initialize the SDK now that BT is on — this is what makes scanning/connecting work
        _initializeSdkWithProfile();
      }
    });

    _fitDaysService.methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'log') {
        final args = call.arguments as Map<dynamic, dynamic>;
        _addLog(args['message'] as String);
      }
    });
  }

  Future<void> _checkPermissionsAndInitialize() async {
    final hasPermissions = await _fitDaysService.checkPermissions();
    setState(() {
      _hasPermissions = hasPermissions;
    });

    if (hasPermissions) {
      await _initializeSdkWithProfile();
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await _fitDaysService.requestPermissions();
    setState(() {
      _hasPermissions = granted;
    });

    if (granted) {
      await _initializeSdkWithProfile();
    }
  }

  Future<void> _initializeSdkWithProfile() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load ALL bound devices (stored as JSON array)
    final boundDevicesJson = prefs.getString('bound_devices');
    if (boundDevicesJson != null) {
      try {
        final List<dynamic> devicesList = jsonDecode(boundDevicesJson);
        setState(() {
          _boundDevices.clear();
          for (var deviceMap in devicesList) {
            _boundDevices.add(FitDaysDevice.fromMap(deviceMap));
          }
        });
        debugPrint('Loaded ${_boundDevices.length} bound devices');
        
        // Auto-connect to first device if available
        if (_boundDevices.isNotEmpty) {
          Future.delayed(const Duration(seconds: 2), () {
             if (mounted && _boundDevices.isNotEmpty && _connectedDevice == null) {
               _connectDevice(_boundDevices.first);
             }
          });
        }
      } catch (e) {
        debugPrint('Error loading bound devices, clearing data: $e');
        await prefs.remove('bound_devices');
      }
    }
    
    // User requested NOT to show previous reading on launch to prevent black screen issues
    // We strictly rely on real-time data from connection
    // await prefs.remove('last_measurement'); // Optional: Clear it if we want to enforce fresh start

    // Use member management data for SDK initialization
    final memberService = MemberService();
    final activeMember = await memberService.ensureMemberExists();
    
    await _fitDaysService.initializeSDK(
      age: activeMember.age,
      height: activeMember.heightCm,
      sex: activeMember.gender.sdkSexType,
    );
  }

  Future<void> _bindDevice(FitDaysDevice device) async {
    // Check if device already bound
    final existingIndex = _boundDevices.indexWhere((d) => d.macAddress == device.macAddress);
    
    if (existingIndex == -1) {
      // New device - add to list
      setState(() {
        _boundDevices.add(device);
      });
    } else {
      // Update existing device
      setState(() {
        _boundDevices[existingIndex] = device;
      });
    }
    
    // Save all bound devices
    final prefs = await SharedPreferences.getInstance();
    final devicesList = _boundDevices.map((d) => d.toMap()).toList();
    final jsonStr = jsonEncode(devicesList);
    await prefs.setString('bound_devices', jsonStr);
    debugPrint('Saved ${_boundDevices.length} bound devices');
    
    // Connect to the newly bound device
    _connectDevice(device);
  }

  Future<void> _unbindDevice(FitDaysDevice device) async {
    // Remove from list
    setState(() {
      _boundDevices.removeWhere((d) => d.macAddress == device.macAddress);
    });
    
    // Disconnect if it's the connected device
    if (_connectedDevice?.macAddress == device.macAddress) {
      await _disconnectDevice();
      setState(() {
        _connectedDevice = null;
      });
    }
    
    // Save updated list
    final prefs = await SharedPreferences.getInstance();
    if (_boundDevices.isEmpty) {
      await prefs.remove('bound_devices');
      await prefs.remove('last_measurement');
    } else {
      final devicesList = _boundDevices.map((d) => d.toMap()).toList();
      final jsonStr = jsonEncode(devicesList);
      await prefs.setString('bound_devices', jsonStr);
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _discoveredDevices.clear();
      _errorMessage = null;
    });
    await _fitDaysService.startScan();
  }

  Future<void> _stopScan() async {
    await _fitDaysService.stopScan();
  }

  Future<void> _connectDevice(FitDaysDevice device) async {
    if (_isScanning) {
      await _stopScan();
    }
    await _fitDaysService.connectDevice(device.macAddress);
  }

  Future<void> _disconnectDevice() async {
    if (_connectedDevice != null) {
      await _fitDaysService.disconnectDevice(_connectedDevice!.macAddress);
    }
  }

  @override
  void dispose() {
    _deviceFoundSub?.cancel();
    _connectionSub?.cancel();
    _weightDataSub?.cancel();
    _scanningSub?.cancel();
    _errorSub?.cancel();
    _bluetoothSub?.cancel();
    _fitDaysService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('My Devices'),
        backgroundColor: AppTheme.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_boundDevices.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: AppTheme.textSecondary),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppTheme.surface1,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppTheme.radiusXxl)),
                  ),
                  builder: (ctx) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Text('Manage Devices', style: AppTheme.headingSM),
                      ),
                      ..._boundDevices.map((device) => ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.purple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_getDeviceIcon(device.deviceType),
                              color: AppTheme.purple, size: 20),
                        ),
                        title: Text(_getDeviceTypeName(device.deviceType),
                            style: AppTheme.headingSM.copyWith(fontSize: 14)),
                        subtitle: Text(device.name, style: AppTheme.bodySM),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppTheme.error),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _unbindDevice(device);
                          },
                        ),
                      )),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: !_hasPermissions
          ? _buildPermissionRequest()
          : _boundDevices.isEmpty
              ? _buildEmptyState()
              : _buildBoundDeviceCard(),
    );
  }

  void _showBluetoothOffSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      routeSettings: const RouteSettings(name: 'bluetooth_off_sheet'),
      builder: (_) => _BluetoothOffSheet(
        onDismiss: () {
          _bluetoothDialogShown = false;
          Navigator.pop(context);
        },
        bluetoothStateStream: _fitDaysService.bluetoothStateStream,
      ),
    ).then((_) {
      _bluetoothDialogShown = false;
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppTheme.lime.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.lime.withOpacity(0.25), width: 1.5),
              ),
              child: const Icon(Icons.monitor_weight_outlined,
                  size: 48, color: AppTheme.lime),
            ),
            const SizedBox(height: 24),
            Text('No device added', style: AppTheme.headingMD),
            const SizedBox(height: 8),
            Text(
              'Connect your FitDays smart scale to track\nbody composition and weight.',
              style: AppTheme.bodyMD,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: _showDeviceScanner,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.lime,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.lime.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text('Add Device',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black)),
              ),
            ),
            const SizedBox(height: 48),
            // Dev-only diagnostic panel — hidden in release/TestFlight builds.
            if (kDebugMode) _buildDebugLog(),
          ],
        ),
      ),
    );
  }

  void _showDeviceScanner() {
    _startScan();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.surface1,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppTheme.radiusXxl)),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(children: [
                          Text('Nearby Devices', style: AppTheme.headingSM),
                          const Spacer(),
                          if (_isScanning)
                            const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.lime),
                            ),
                        ]),
                      ),
                      Divider(height: 1,
                          color: Colors.white.withOpacity(0.06)),
                      Expanded(
                        child: StreamBuilder<FitDaysDevice>(
                          stream: _fitDaysService.deviceFoundStream,
                          builder: (context, snapshot) {
                            if (_discoveredDevices.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 32, height: 32,
                                      child: CircularProgressIndicator(
                                          color: AppTheme.lime,
                                          strokeWidth: 2),
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Scanning for devices…',
                                        style: AppTheme.bodyMD),
                                  ],
                                ),
                              );
                            }
                            return ListView.separated(
                              controller: scrollController,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _discoveredDevices.length,
                              separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.04),
                                  indent: 72),
                              itemBuilder: (context, index) {
                                final device = _discoveredDevices[index];
                                return ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 6),
                                  leading: Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.lime.withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                        _getDeviceIcon(device.deviceType),
                                        color: AppTheme.lime, size: 22),
                                  ),
                                  title: Text(
                                    _getDeviceTypeName(device.deviceType),
                                    style: AppTheme.headingSM
                                        .copyWith(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    '${device.name} · ${device.macAddress}',
                                    style: AppTheme.bodySM,
                                  ),
                                  trailing: GestureDetector(
                                    onTap: () {
                                      _bindDevice(device);
                                      Navigator.pop(context);
                                    },
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.lime,
                                        borderRadius: BorderRadius.circular(
                                            AppTheme.radiusPill),
                                      ),
                                      child: const Text('Add',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.black)),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(_stopScan);
  }

  Widget _buildBoundDeviceCard() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._boundDevices.map(_buildDeviceCard),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: GestureDetector(
            onTap: _showDeviceScanner,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded,
                      color: AppTheme.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  Text('Add another device', style: AppTheme.labelLG),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(FitDaysDevice device) {
    final isConnected = _connectedDevice?.macAddress == device.macAddress;

    void onTap() {
      if (device.deviceType == DeviceType.kitchenScale) {
        if (!isConnected) _connectDevice(device);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => KitchenScaleScreen(
            connectedDevice: device, fitDaysService: _fitDaysService),
        ));
      } else {
        if (!isConnected) _connectDevice(device);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => MeasurementScreen(
            connectedDevice: device, fitDaysService: _fitDaysService),
        ));
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: isConnected
                ? AppTheme.lime.withOpacity(0.3)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: Row(children: [
          // Device icon
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: isConnected
                  ? AppTheme.lime.withOpacity(0.12)
                  : AppTheme.purple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getDeviceIcon(device.deviceType),
              size: 26,
              color: isConnected ? AppTheme.lime : AppTheme.purple,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getDeviceTypeName(device.deviceType),
                    style: AppTheme.headingSM),
                const SizedBox(height: 3),
                Text(device.name,
                    style: AppTheme.bodyMD),
                const SizedBox(height: 6),
                Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: isConnected ? AppTheme.lime : AppTheme.textTertiary,
                      shape: BoxShape.circle,
                      boxShadow: isConnected
                          ? [BoxShadow(
                                color: AppTheme.lime.withOpacity(0.6),
                                blurRadius: 6)]
                          : [],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? 'Connected' : 'Tap to connect',
                    style: AppTheme.bodySM.copyWith(
                      color: isConnected
                          ? AppTheme.lime
                          : AppTheme.textTertiary,
                      fontWeight: isConnected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppTheme.textTertiary, size: 20),
        ]),
      ),
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.kitchenScale:
        return Icons.kitchen;
      case DeviceType.bodyFatScale:
        return Icons.monitor_weight;
      case DeviceType.heightRuler:
        return Icons.straighten;
      case DeviceType.skippingRope:
        return Icons.sports;
      default:
        return Icons.device_unknown;
    }
  }

  String _getDeviceTypeName(DeviceType type) {
    switch (type) {
      case DeviceType.kitchenScale:
        return 'Kitchen Scale';
      case DeviceType.bodyFatScale:
        return 'Body Fat Scale';
      case DeviceType.heightRuler:
        return 'Height Ruler';
      case DeviceType.skippingRope:
        return 'Skipping Rope';
      default:
        return 'Unknown Device';
    }
  }
  
  Widget _buildQuickStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
  
  Widget _buildMetricsList(WeightMeasurement m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Body Index', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: 16),
        _buildMetricTile('BMI', m.bmi?.toStringAsFixed(1), Icons.monitor_weight, Colors.blue),
        _buildMetricTile('Body Fat', '${m.bodyFat?.toStringAsFixed(1)}%', Icons.opacity, Colors.orange),
        _buildMetricTile('Muscle Rate', '${m.muscle?.toStringAsFixed(1)}%', Icons.fitness_center, Colors.blueAccent),
        _buildMetricTile('Body Water', '${m.water?.toStringAsFixed(1)}%', Icons.water_drop, Colors.cyan),
        _buildMetricTile('Bone Mass', '${m.boneMass?.toStringAsFixed(1)} kg', Icons.accessibility_new, Colors.grey),
        _buildMetricTile('BMR', '${m.bmr} kcal', Icons.local_fire_department, Colors.red),
        _buildMetricTile('Visceral Fat', m.visceralFat?.toStringAsFixed(1), Icons.layers, Colors.purple),
        _buildMetricTile('Protein', '${m.protein?.toStringAsFixed(1)}%', Icons.egg, Colors.yellow[700]),
        _buildMetricTile('Body Age', '${m.physicalAge}', Icons.person, Colors.green),
      ],
    );
  }
  
  Widget _buildMetricTile(String title, String? value, IconData icon, Color? color) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.blue.withOpacity(0.25), width: 1.5),
              ),
              child: const Icon(Icons.bluetooth_disabled_rounded,
                  size: 44, color: Colors.blueAccent),
            ),
            const SizedBox(height: 24),
            Text('Bluetooth access needed',
                style: AppTheme.headingMD, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'EleFit needs Bluetooth permission to scan and connect to your smart scale.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMD.copyWith(height: 1.6),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: _requestPermissions,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.lime,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.lime.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text('Grant Permission',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugLog() {
    return Container(
      height: 100,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: _debugLogs.length,
        reverse: true,
        itemBuilder: (context, index) {
          final log = _debugLogs[_debugLogs.length - 1 - index];
          return Text(
            log,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
          );
        },
      ),
    );
  }
}

class _BluetoothOffSheet extends StatefulWidget {
  final VoidCallback onDismiss;
  final Stream<bool> bluetoothStateStream;

  const _BluetoothOffSheet({
    required this.onDismiss,
    required this.bluetoothStateStream,
  });

  @override
  State<_BluetoothOffSheet> createState() => _BluetoothOffSheetState();
}

class _BluetoothOffSheetState extends State<_BluetoothOffSheet> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    // Auto-dismiss when BT turns on
    _sub = widget.bluetoothStateStream.listen((isOn) {
      if (isOn && mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.withOpacity(0.25), width: 1.5),
            ),
            child: const Icon(Icons.bluetooth_disabled, size: 44, color: Colors.blueAccent),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bluetooth is Off',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            'Please enable Bluetooth to scan and\nconnect to your smart devices.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          // Instruction card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.bluetooth, color: Colors.blueAccent, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Go to Settings → Bluetooth\nand toggle it on, then return here.',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Waiting indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.blueAccent)),
              const SizedBox(width: 10),
              Text('Waiting for Bluetooth...', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onDismiss,
            child: Text('Dismiss', style: TextStyle(color: Colors.white.withOpacity(0.35), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
    );
  }
}
