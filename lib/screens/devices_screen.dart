import 'dart:convert';
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fitDaysService = FitDaysService();
    _setupListeners();
    _checkPermissionsAndInitialize();
  }

  void _setupListeners() {
    // Listen for discovered devices
    _fitDaysService.deviceFoundStream.listen((device) {
      _addLog('Device: ${device.macAddress}');
      print('Device found: ${device.macAddress}');
      setState(() {
        if (!_discoveredDevices.any((d) => d.macAddress == device.macAddress)) {
          _discoveredDevices.add(device);
        }
      });
    });

    // Listen for connection state changes
    _fitDaysService.connectionStateStream.listen((data) {
      final macAddress = data['macAddress'] as String;
      final state = data['state'] as String;
      _addLog('Conn: $macAddress -> $state');
      print('Connection state changed: $macAddress -> $state');

      setState(() {
        // Update discovered devices list
        final deviceIndex = _discoveredDevices
            .indexWhere((d) => d.macAddress == macAddress);
        
        if (deviceIndex != -1) {
          DeviceConnectionState connectionState;
          switch (state) {
            case 'connected':
              connectionState = DeviceConnectionState.connected;
              _connectedDevice = _discoveredDevices[deviceIndex];
              // NAVIGATE TO APPROPRIATE SCREEN BASED ON DEVICE TYPE
              if (mounted) {
                 if (_connectedDevice!.deviceType == DeviceType.kitchenScale) {
                   // Kitchen scale -> Food tracking screen
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (_) => KitchenScaleScreen(
                         connectedDevice: _connectedDevice!,
                         fitDaysService: _fitDaysService,
                       ),
                     ),
                   );
                 } else {
                   // Body fat scale -> Measurement screen
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (_) => MeasurementScreen(
                         connectedDevice: _connectedDevice!,
                         fitDaysService: _fitDaysService,
                       ),
                     ),
                   );
                 }
              }
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
        
        // CRITICAL: Also update bound device state
        final boundDeviceIndex = _boundDevices.indexWhere((d) => d.macAddress == macAddress);
        if (boundDeviceIndex != -1) {
          switch (state) {
            case 'connected':
              _connectedDevice = _boundDevices[boundDeviceIndex];
              // Navigate to appropriate screen based on device type
              if (mounted) {
                 if (_connectedDevice!.deviceType == DeviceType.kitchenScale) {
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (_) => KitchenScaleScreen(
                         connectedDevice: _connectedDevice!,
                         fitDaysService: _fitDaysService,
                       ),
                     ),
                   );
                 } else {
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (_) => MeasurementScreen(
                         connectedDevice: _connectedDevice!,
                         fitDaysService: _fitDaysService,
                       ),
                     ),
                   );
                 }
              }
              break;
            case 'disconnected':
              _connectedDevice = null;
              // Try to reconnect after a delay
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted && _boundDevices.isNotEmpty && _connectedDevice == null) {
                  _connectDevice(_boundDevices[boundDeviceIndex]);
                }
              });
              break;
          }
        }
      });
    });

    // Listen for weight data
    _fitDaysService.weightDataStream.listen((measurement) async {
      _addLog('Weight: ${measurement.weight} ${measurement.unit}');
      print('Weight data received: ${measurement.weight} ${measurement.unit}, Stabilized: ${measurement.isStabilized}');
      
      setState(() {
        _latestMeasurement = measurement;
      });
      
      // Persist stabilized data or any data if user wants "previous reading"
      // Usually we only save stabilized data for history, but for "current state" per user request
      // we might want the last valid reading.
      // Let's save it if it has body composition (means it's a complete reading) OR if it is stabilized.
      if (measurement.isStabilized) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('last_measurement', jsonEncode(measurement.toMap()));
      }
    });

    // Listen for scanning state
    _fitDaysService.scanningStream.listen((isScanning) {
      _addLog('Scanning: $isScanning');
      print('Scanning state: $isScanning');
      setState(() {
        _isScanning = isScanning;
      });
    });

    // Listen for errors
    _fitDaysService.errorStream.listen((error) {
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

    // Listen for debug logs from native
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
        print('Loaded ${_boundDevices.length} bound devices');
        
        // Auto-connect to first device if available
        if (_boundDevices.isNotEmpty) {
          Future.delayed(const Duration(seconds: 2), () {
             if (mounted && _boundDevices.isNotEmpty && _connectedDevice == null) {
               _connectDevice(_boundDevices.first);
             }
          });
        }
      } catch (e) {
        print('Error loading bound devices, clearing data: $e');
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
    print('Saved ${_boundDevices.length} bound devices');
    
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
    _fitDaysService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Health', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_boundDevices.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.grey),
              onPressed: () {
                 // Option to manage devices
                 showModalBottomSheet(context: context, builder: (ctx) {
                   return Container(
                     padding: const EdgeInsets.all(16),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text('Manage Devices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 16),
                         ..._boundDevices.map((device) => ListTile(
                           leading: Icon(_getDeviceIcon(device.deviceType)),
                           title: Text(_getDeviceTypeName(device.deviceType)),
                           subtitle: Text(device.name),
                           trailing: IconButton(
                             icon: const Icon(Icons.delete, color: Colors.red),
                             onPressed: () {
                               Navigator.pop(ctx);
                               _unbindDevice(device);
                             },
                           ),
                         )).toList(),
                         const SizedBox(height: 8),
                         ListTile(
                           leading: const Icon(Icons.close),
                           title: const Text('Cancel'),
                           onTap: () => Navigator.pop(ctx),
                         ),
                       ],
                     ),
                   );
                 });
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
             padding: const EdgeInsets.all(24),
             decoration: BoxDecoration(
               color: AppTheme.primaryColor.withOpacity(0.1),
               shape: BoxShape.circle,
             ),
             child: const Icon(Icons.add_circle_outline, size: 64, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Device Added',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a smart scale to track your health.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _showDeviceScanner,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Add Device', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 48),
          _buildDebugLog(), // Keep debug log accessible
        ],
      ),
    );
  }

  void _showDeviceScanner() {
    _startScan();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Text(
                            'Select Device',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_isScanning)
                            const SizedBox(
                              width: 20, 
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: StreamBuilder<FitDaysDevice>(
                        stream: _fitDaysService.deviceFoundStream,
                        builder: (context, snapshot) {
                          // Note: The main screen state handles the list, 
                          // but since we are in a modal, we might need to rely on 
                          // the parent state's _discoveredDevices which is updated by the stream listener 
                          // in the parent widget.
                          // However, StatefulBuilder doesn't auto-rebuild when parent state changes 
                          // unless we pass data down. 
                          // Actually, simply using the parent's `_discoveredDevices` directly works 
                          // IF we call `setModalState` when new devices arrive.
                          // But our stream listener calls `setState` on the parent. 
                          // Let's use a ValueListenable or just listen to the list length if we could.
                          // Simplest approach: Use the list we have. 
                          // Since parent setState usually rebuilds the tree, 
                          // it might NOT rebuild the modal contents if they are an overlay.
                          // Ideally we should move scanning logic here or use a Provider.
                          // For now, let's rely on standard ListView building from _discoveredDevices
                          // If it doesn't update, we'll need to wrap this in a listenable.
                          
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: _discoveredDevices.length,
                            itemBuilder: (context, index) {
                              final device = _discoveredDevices[index];
                              final deviceIcon = _getDeviceIcon(device.deviceType);
                              final deviceTypeName = _getDeviceTypeName(device.deviceType);
                              
                              return ListTile(
                                leading: Icon(deviceIcon, color: AppTheme.primaryColor),
                                title: Text(deviceTypeName),
                                subtitle: Text('${device.name}\n${device.macAddress}'),
                                isThreeLine: true,
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    _bindDevice(device);
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                  ),
                                  child: const Text('Add'),
                                ),
                              );
                            },
                          );
                        }
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      _stopScan();
    });
  }

  Widget _buildBoundDeviceCard() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Show ALL bound devices
              ..._boundDevices.map((device) => _buildDeviceCard(device)).toList(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showDeviceScanner,
              icon: const Icon(Icons.add),
              label: const Text('Add Device'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(FitDaysDevice device) {
    final isConnected = _connectedDevice?.macAddress == device.macAddress;
    final deviceIcon = _getDeviceIcon(device.deviceType);
    final deviceTypeName = _getDeviceTypeName(device.deviceType);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Special handling for Kitchen Scale: Always open screen
          if (device.deviceType == DeviceType.kitchenScale) {
            if (!isConnected) {
              _connectDevice(device);
            }
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KitchenScaleScreen(
                  connectedDevice: device,
                  fitDaysService: _fitDaysService,
                ),
              ),
            );
          } else {
            // Other devices: Connect first, then navigate
            if (!isConnected) {
              _connectDevice(device);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MeasurementScreen(
                    connectedDevice: device,
                    fitDaysService: _fitDaysService,
                  ),
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(deviceIcon, size: 32, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceTypeName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.name,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isConnected ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            color: isConnected ? Colors.green : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bluetooth_disabled,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'Bluetooth Permissions Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'This app needs Bluetooth permissions to scan and connect to weight devices.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _requestPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'Grant Permissions',
                style: TextStyle(fontSize: 16),
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
        reverse: true, // Show new logs at bottom/start
        itemBuilder: (context, index) {
          // Reverse index for display
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
