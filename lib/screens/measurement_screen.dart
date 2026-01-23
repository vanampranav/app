import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../services/fitdays_service.dart';
import '../theme/app_theme.dart';

class MeasurementScreen extends StatefulWidget {
  final FitDaysDevice connectedDevice;
  final FitDaysService fitDaysService;

  const MeasurementScreen({
    Key? key,
    required this.connectedDevice,
    required this.fitDaysService,
  }) : super(key: key);

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  WeightMeasurement? _latestMeasurement;
  final List<String> _debugLogs = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void dispose() {
    // DON'T disconnect - let the connection stay alive for auto-reconnect
    // The DevicesScreen will handle reconnection when device comes back online
    // widget.fitDaysService.disconnectDevice(widget.connectedDevice.macAddress);
    super.dispose();
  }

  void _setupListeners() {
    widget.fitDaysService.weightDataStream.listen((measurement) {
      if (mounted) {
        setState(() {
          _latestMeasurement = measurement;
          _addLog("Weight: ${measurement.weight} ${measurement.unit}");
        });
      }
    });

    // Also listen for logs passed from previous screen or service
    widget.fitDaysService.methodChannel.setMethodCallHandler((call) async {
       if (call.method == 'log') {
         final args = call.arguments as Map<dynamic, dynamic>;
         _addLog(args['message'] as String);
       }
    });
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _debugLogs.add(message);
      if (_debugLogs.length > 20) _debugLogs.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.connectedDevice.name),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildWeightDisplay(),
            const SizedBox(height: 32),
            if (_latestMeasurement != null && _latestMeasurement!.hasBodyComposition)
              _buildMetricsList(_latestMeasurement!),
            if (_latestMeasurement == null)
               const Text("Waiting for data... Step on scale.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            _buildDebugLog(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightDisplay() {
    // Kitchen scales need more precision (e.g., 57.4g), body scales use 1 decimal (e.g., 70.5kg)
    final isKitchenScale = widget.connectedDevice.deviceType == DeviceType.kitchenScale;
    final weight = _latestMeasurement?.weight.toString() ?? "0.0";
    final unit = _latestMeasurement?.unit ?? "kg";
    
    return Column(
      children: [
        Text(weight, style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold)),
        Text(unit, style: const TextStyle(fontSize: 24, color: Colors.grey)),
        if (_latestMeasurement?.isStabilized == true)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
            child: const Text("Stabilized", style: TextStyle(color: Colors.white)),
          )
      ],
    );
  }

  Widget _buildMetricsList(WeightMeasurement m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildMetricRow("BMI", m.bmi?.toStringAsFixed(1)),
        _buildMetricRow("Body Fat", "${m.bodyFat?.toStringAsFixed(1)}%"),
        _buildMetricRow("Muscle", "${m.muscle?.toStringAsFixed(1)}%"),
        _buildMetricRow("Water", "${m.water?.toStringAsFixed(1)}%"),
        _buildMetricRow("Bone Mass", "${m.boneMass?.toStringAsFixed(1)} kg"),
        // Add other metrics as needed
      ],
    );
  }

  Widget _buildMetricRow(String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDebugLog() {
    return Container(
      height: 150,
      width: double.infinity,
      color: Colors.black12,
      child: ListView.builder(
        itemCount: _debugLogs.length,
        itemBuilder: (ctx, i) => Text(_debugLogs[i], style: const TextStyle(fontSize: 10)),
      ),
    );
  }
}
