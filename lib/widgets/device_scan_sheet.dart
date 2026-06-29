import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_model.dart';
import '../services/fitdays_service.dart';
import '../services/member_service.dart';
import '../models/member_model.dart';
import '../theme/app_theme.dart';

/// Reusable bottom sheet that scans for FitDays BLE devices and connects.
///
/// [filterType]  - optional filter (e.g. DeviceType.kitchenScale).
///                 Pass null to show all device types.
/// [onConnected] - called with the FitDaysDevice once connected.
///                 The caller is responsible for closing the sheet.
class DeviceScanSheet extends StatefulWidget {
  final DeviceType? filterType;
  final String? title;
  final String? subtitle;
  final void Function(FitDaysDevice device)? onConnected;

  const DeviceScanSheet({
    Key? key,
    this.filterType,
    this.title,
    this.subtitle,
    this.onConnected,
  }) : super(key: key);

  @override
  State<DeviceScanSheet> createState() => _DeviceScanSheetState();
}

class _DeviceScanSheetState extends State<DeviceScanSheet> {
  final FitDaysService _fitDays = FitDaysService();

  final List<FitDaysDevice> _devices = [];
  FitDaysDevice? _connecting;
  bool _isScanning    = false;
  bool _hasPermissions = false;
  bool _isBluetoothOn  = true; // optimistic until stream says otherwise
  bool _permCheckDone  = false;

  StreamSubscription? _deviceSub;
  StreamSubscription? _connSub;
  StreamSubscription? _scanningSub;
  StreamSubscription? _btSub;
  StreamSubscription? _weightSub;
  Timer? _streamTick;

  @override
  void initState() {
    super.initState();
    _setupDeviceListeners();
    // Re-evaluate "is the scale actually streaming" on each reading + every 2s
    // (so it flips back to off when the scale goes silent / is powered off).
    _weightSub = _fitDays.weightDataStream.listen((_) {
      if (mounted) setState(() {});
    });
    _streamTick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
    _init();
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _connSub?.cancel();
    _scanningSub?.cancel();
    _btSub?.cancel();
    _weightSub?.cancel();
    _streamTick?.cancel();
    _fitDays.stopScan();
    super.dispose();
  }

  /// Whether the scale is genuinely reachable RIGHT NOW (not a stale connection).
  /// Kitchen scales stream continuously when on, so streaming = on. Body-fat
  /// scales only send on weigh-in, so fall back to the connection state.
  bool get _scaleReachable => widget.filterType == DeviceType.kitchenScale
      ? _fitDays.isScaleStreaming
      : _fitDays.hasConnectedDevice;

  // ── Initialise: permissions → SDK profile → Bluetooth check → scan ────────
  Future<void> _init() async {
    // 1. Bluetooth permissions — ask only once per app install
    bool perms = await _fitDays.checkPermissions();
    if (!perms) {
      perms = await _fitDays.requestPermissions();
    }
    if (mounted) setState(() { _hasPermissions = perms; _permCheckDone = true; });
    if (!perms) return; // can't proceed without permissions

    // 2. Initialise SDK with user profile so BIA works correctly
    try {
      final member = await MemberService().ensureMemberExists();
      await _fitDays.initializeSDK(
        age:    member.age,
        height: member.heightCm,
        sex:    member.gender.sdkSexType,
      );
    } catch (_) {}

    // 3. Watch Bluetooth state
    final currentBt = _fitDays.isBluetoothOn;
    if (mounted && currentBt != null) {
      setState(() => _isBluetoothOn = currentBt);
    }
    _btSub = _fitDays.bluetoothStateStream.listen((isOn) {
      if (!mounted) return;
      setState(() => _isBluetoothOn = isOn);
      if (isOn && _hasPermissions && !_isScanning) {
        _loadBoundDevices();
        _startScan();
      }
    });

    // 4. Load already-paired devices immediately
    await _loadBoundDevices();

    // 5. Start scanning if Bluetooth is on
    if (_isBluetoothOn) await _startScan();
  }

  // ── Pre-populate with devices the user has already paired ─────────────────
  Future<void> _loadBoundDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('bound_devices');
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => FitDaysDevice.fromMap(e as Map<String, dynamic>))
          .where(_passesFilter)
          .toList();
      if (mounted) {
        setState(() {
          for (final d in list) {
            if (!_devices.any((x) => x.macAddress == d.macAddress)) {
              _devices.add(d);
            }
          }
        });
      }
    } catch (_) {}
  }

  void _setupDeviceListeners() {
    _deviceSub = _fitDays.deviceFoundStream.listen((d) {
      if (!mounted || !_passesFilter(d)) return;
      setState(() {
        // BLE scales rotate their MAC address. A saved (bound) device may have a
        // STALE MAC — connecting to it "succeeds" at the SDK but never streams
        // weight. So when a live scan finds the same-named device with a new MAC,
        // drop the stale entry and keep the live one.
        if (d.name.isNotEmpty) {
          _devices.removeWhere(
              (x) => x.name == d.name && x.macAddress != d.macAddress);
        }
        if (!_devices.any((x) => x.macAddress == d.macAddress)) {
          _devices.add(d);
        }
      });
    });

    _connSub = _fitDays.connectionStateStream.listen((data) {
      if (!mounted) return;
      final state = data['state'] as String?;
      final mac   = data['macAddress'] as String?;
      if (state == 'connected' && mac != null) {
        final device = _devices.firstWhere(
          (d) => d.macAddress == mac,
          orElse: () => _connecting ?? _devices.first,
        );
        _saveBoundDevice(device);
        setState(() => _connecting = null);
        widget.onConnected?.call(device);
      } else if (state == 'disconnected') {
        if (mounted) setState(() => _connecting = null);
      }
    });

    _scanningSub = _fitDays.scanningStream.listen((s) {
      if (mounted) setState(() => _isScanning = s);
    });
  }

  bool _passesFilter(FitDaysDevice d) =>
      widget.filterType == null || d.deviceType == widget.filterType;

  Future<void> _startScan() async {
    await _fitDays.startScan();
  }

  Future<void> _connect(FitDaysDevice device) async {
    setState(() => _connecting = device);
    await _fitDays.stopScan();
    await _fitDays.connectDevice(device.macAddress);
  }

  Future<void> _saveBoundDevice(FitDaysDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('bound_devices');
    List<Map<String, dynamic>> list = [];
    if (raw != null) {
      try {
        list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    // Drop any stale entry for the same device name (its MAC may have rotated)
    // so we always store the current, live MAC.
    list.removeWhere((m) =>
        (m['name'] == device.name && m['macAddress'] != device.macAddress) ||
        m['macAddress'] == device.macAddress);
    list.add(device.toMap());
    await prefs.setString('bound_devices', jsonEncode(list));
  }

  // ── Shared container wrapper ──────────────────────────────────────────────
  Widget _shell({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXxl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title ?? 'Connect Scale', style: AppTheme.headingSM),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(widget.subtitle!, style: AppTheme.bodySM),
              ],
            ]),
          ]),
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.06)),
        child,
      ]),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Permissions not yet determined — show spinner
    if (!_permCheckDone) {
      return _shell(child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: AppTheme.lime)),
      ));
    }

    // Permissions denied
    if (!_hasPermissions) {
      return _shell(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bluetooth_disabled_rounded,
              color: AppTheme.textTertiary, size: 48),
          const SizedBox(height: 16),
          Text('Bluetooth permission required', style: AppTheme.headingSM,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Grant Bluetooth access in your phone Settings to scan for scales.',
            style: AppTheme.bodyMD, textAlign: TextAlign.center,
          ),
        ]),
      ));
    }

    // Bluetooth off
    if (!_isBluetoothOn) {
      return _shell(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.withOpacity(0.25), width: 1.5),
            ),
            child: const Icon(Icons.bluetooth_disabled_rounded,
                color: Colors.blueAccent, size: 36),
          ),
          const SizedBox(height: 20),
          Text('Bluetooth is off', style: AppTheme.headingMD),
          const SizedBox(height: 8),
          Text('Turn on Bluetooth to scan for your scale.',
              style: AppTheme.bodyMD, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  color: Colors.blueAccent, strokeWidth: 1.5),
            ),
            const SizedBox(width: 10),
            Text('Waiting for Bluetooth…',
                style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary)),
          ]),
        ]),
      ));
    }

    // Only treat as connected when the scale is genuinely reachable — a stale
    // BLE connection lingers after the scale powers off.
    final alreadyConnectedMac = _scaleReachable ? _fitDays.connectedDeviceMac : null;
    // Kitchen scale is off (not streaming) once BT + permissions are ready.
    final scaleIsOff = widget.filterType == DeviceType.kitchenScale &&
        _isBluetoothOn &&
        _hasPermissions &&
        !_fitDays.isScaleStreaming;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXxl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
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
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title ?? 'Connect Scale',
                  style: AppTheme.headingSM),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(widget.subtitle!, style: AppTheme.bodySM),
              ],
            ]),
            const Spacer(),
            if (_isScanning)
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: AppTheme.lime, strokeWidth: 2)),
          ]),
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.06)),

        // Scale is off — prompt the user to power it on (kitchen scale streams
        // continuously when on, so "not streaming" = off).
        if (scaleIsOff) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              const Icon(Icons.power_settings_new_rounded,
                  color: AppTheme.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Please turn on your scale',
                      style: AppTheme.bodyMD.copyWith(color: AppTheme.warning, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Power on your scale and keep it nearby — it will connect automatically.',
                      style: AppTheme.bodySM),
                ]),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(color: AppTheme.warning, strokeWidth: 2)),
            ]),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.04)),
        ],

        // Already connected banner
        if (alreadyConnectedMac != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.lime, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Scale already connected',
                  style: AppTheme.bodyMD.copyWith(color: AppTheme.lime)),
              const Spacer(),
              GestureDetector(
                // Just proceed — the device is already connected. Do NOT call
                // connectDevice/addDevice again: the FitDays SDK requires a
                // removeDevice before re-adding, and re-adding an already-added
                // device corrupts its state and stops ALL measurement delivery.
                onTap: () {
                  final mac = alreadyConnectedMac;
                  final device = _devices.firstWhere(
                    (d) => d.macAddress == mac,
                    orElse: () => FitDaysDevice(
                      macAddress: mac,
                      name: 'Scale',
                      rssi: 0,
                      deviceType: widget.filterType ?? DeviceType.kitchenScale,
                    ),
                  );
                  if (widget.onConnected != null) {
                    widget.onConnected!(device);
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.lime,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: const Text('Use it',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.black)),
                ),
              ),
            ]),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.04)),
        ],

        // Device list or empty state
        if (_devices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              Icon(
                widget.filterType == DeviceType.bodyFatScale
                    ? Icons.monitor_weight_outlined
                    : Icons.kitchen_rounded,
                color: AppTheme.textTertiary, size: 44,
              ),
              const SizedBox(height: 14),
              Text('Looking for devices…', style: AppTheme.headingSM),
              const SizedBox(height: 6),
              Text('Make sure your scale is powered on.',
                  style: AppTheme.bodyMD),
            ]),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _devices.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.white.withOpacity(0.04),
                indent: 72),
            itemBuilder: (_, i) {
              final d = _devices[i];
              final isConnected  = alreadyConnectedMac == d.macAddress;
              final isConnecting = _connecting?.macAddress == d.macAddress;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 6),
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppTheme.lime.withOpacity(0.12)
                        : AppTheme.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    d.deviceType == DeviceType.kitchenScale
                        ? Icons.kitchen_rounded
                        : Icons.monitor_weight_rounded,
                    color: isConnected ? AppTheme.lime : AppTheme.textSecondary,
                    size: 22,
                  ),
                ),
                title: Text(
                  d.deviceType == DeviceType.kitchenScale
                      ? 'Kitchen Scale'
                      : d.deviceType == DeviceType.bodyFatScale
                          ? 'Body Fat Scale'
                          : 'Smart Scale',
                  style: AppTheme.headingSM.copyWith(fontSize: 14),
                ),
                subtitle: Text(d.name, style: AppTheme.bodySM),
                trailing: isConnected
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.lime.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusPill),
                          border: Border.all(
                              color: AppTheme.lime.withOpacity(0.35)),
                        ),
                        child: Text('Connected',
                            style: AppTheme.labelMD
                                .copyWith(color: AppTheme.lime)),
                      )
                    : isConnecting
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: AppTheme.lime, strokeWidth: 2))
                        : GestureDetector(
                            onTap: () => _connect(d),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppTheme.lime,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusPill),
                              ),
                              child: const Text('Connect',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black)),
                            ),
                          ),
              );
            },
          ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
