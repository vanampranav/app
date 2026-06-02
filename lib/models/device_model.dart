import 'member_model.dart';

// FitDays Device Models
// Represents Bluetooth devices and their data

enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
}

enum DeviceType {
  unknown,
  kitchenScale,
  bodyFatScale,
  heightRuler,
  skippingRope,
}

class FitDaysDevice {
  final String name;
  final String macAddress;
  final int rssi;
  DeviceConnectionState connectionState;
  final DeviceType deviceType;

  FitDaysDevice({
    required this.name,
    required this.macAddress,
    required this.rssi,
    this.connectionState = DeviceConnectionState.disconnected,
    this.deviceType = DeviceType.unknown,
  });

  factory FitDaysDevice.fromMap(Map<String, dynamic> map) {
    // Determine device type
    DeviceType type = DeviceType.unknown;
    
    // 1. Try to use strict type from Native SDK if available
    if (map.containsKey('type')) {
      final nativeType = map['type'].toString();
      if (nativeType.contains('KitchenScale')) {
        type = DeviceType.kitchenScale;
      } else if (nativeType.contains('FatScale') || nativeType.contains('BodyFat')) {
        type = DeviceType.bodyFatScale; 
      } else if (nativeType.contains('Ruler')) {
        type = DeviceType.heightRuler;
      } else if (nativeType.contains('Skip') || nativeType.contains('Rope')) {
        type = DeviceType.skippingRope;
      }
    }

    // 2. Fallback to Name-based detection if unknown
    if (type == DeviceType.unknown) {
      final deviceName = (map['name'] as String? ?? '').toLowerCase();
      if (deviceName.contains('kitchen') || deviceName == 'my_scale') {
        type = DeviceType.kitchenScale;
      } else if (deviceName.contains('fat') || deviceName.contains('body') || deviceName.contains('composition')) {
        type = DeviceType.bodyFatScale;
      } else if (deviceName.contains('ruler') || deviceName.contains('height')) {
        type = DeviceType.heightRuler;
      } else if (deviceName.contains('skip') || deviceName.contains('rope')) {
        type = DeviceType.skippingRope;
      } else if (deviceName.contains('scale')) {
        type = DeviceType.bodyFatScale;
      }
    }

    return FitDaysDevice(
      name: map['name'] as String? ?? 'Unknown Device',
      macAddress: map['macAddress'] as String? ?? '',
      rssi: map['rssi'] as int? ?? 0,
      deviceType: type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'macAddress': macAddress,
      'rssi': rssi,
      'type': deviceType.toString(),
    };
  }

  String toJson() => toString(); // Placeholder if used by jsonEncode, but we'll use manual map serialization for SharedPreferences

  FitDaysDevice copyWith({
    String? name,
    String? macAddress,
    int? rssi,
    DeviceConnectionState? connectionState,
    DeviceType? deviceType,
  }) {
    return FitDaysDevice(
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      rssi: rssi ?? this.rssi,
      connectionState: connectionState ?? this.connectionState,
      deviceType: deviceType ?? this.deviceType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FitDaysDevice && other.macAddress == macAddress;
  }

  @override
  int get hashCode => macAddress.hashCode;
}

/// Which physical device produced a WeightMeasurement.
/// Set by FitDaysService when routing native SDK events.
enum WeightSource { bodyFatScale, kitchenScale, unknown }

class WeightMeasurement {
  final double weight;
  final String unit;
  final bool isStabilized;
  final double? bmi;
  final double? bodyFat;
  final double? muscle;
  final double? water;
  final double? boneMass;
  final double? protein;
  final int? bmr;
  final double? visceralFat;
  final double? skeletalMuscle;
  final int? physicalAge;
  final DateTime timestamp;

  /// Identifies which device type sent this measurement so screens can
  /// ignore readings from the wrong device even when both are connected.
  final WeightSource source;

  WeightMeasurement({
    required this.weight,
    required this.unit,
    required this.isStabilized,
    this.bmi,
    this.bodyFat,
    this.muscle,
    this.water,
    this.boneMass,
    this.protein,
    this.bmr,
    this.visceralFat,
    this.skeletalMuscle,
    this.physicalAge,
    DateTime? timestamp,
    this.source = WeightSource.unknown,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WeightMeasurement.fromMap(Map<String, dynamic> map,
      {WeightSource source = WeightSource.unknown}) {
    return WeightMeasurement(
      weight: (map['weight'] as num).toDouble(),
      unit: map['unit'] as String? ?? 'kg',
      isStabilized: map['isStabilized'] as bool? ?? false,
      bmi: map['bmi'] != null ? (map['bmi'] as num).toDouble() : null,
      bodyFat: map['bodyFat'] != null ? (map['bodyFat'] as num).toDouble() : null,
      muscle: map['muscle'] != null ? (map['muscle'] as num).toDouble() : null,
      water: map['water'] != null ? (map['water'] as num).toDouble() : null,
      boneMass: map['boneMass'] != null ? (map['boneMass'] as num).toDouble() : null,
      protein: map['protein'] != null ? (map['protein'] as num).toDouble() : null,
      bmr: (map['bmr'] as num?)?.toInt(),
      visceralFat: map['visceralFat'] != null ? (map['visceralFat'] as num).toDouble() : null,
      skeletalMuscle: map['skeletalMuscle'] != null ? (map['skeletalMuscle'] as num).toDouble() : null,
      physicalAge: (map['physicalAge'] as num?)?.toInt(),
      source: source,
    );
  }

  factory WeightMeasurement.fromBodyMeasurement(BodyMeasurement measurement) {
    return WeightMeasurement(
      weight: measurement.weightKg,
      unit: 'kg', // Stored measurements are in kg
      isStabilized: true, // Stored measurements are stable
      bmi: measurement.bmi,
      bodyFat: measurement.bodyFatPercent,
      muscle: measurement.muscleRatePercent,
      water: measurement.bodyWaterPercent,
      boneMass: measurement.boneMassKg,
      protein: measurement.proteinPercent,
      bmr: measurement.bmr,
      visceralFat: measurement.visceralFat,
      skeletalMuscle: measurement.skeletalMusclePercent,
      physicalAge: measurement.bodyAge,
      timestamp: measurement.timestamp,
    );
  }

  bool get hasBodyComposition => bmi != null && bodyFat != null;

  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'unit': unit,
      'isStabilized': isStabilized,
      'bmi': bmi,
      'bodyFat': bodyFat,
      'muscle': muscle,
      'water': water,
      'boneMass': boneMass,
      'protein': protein,
      'bmr': bmr,
      'visceralFat': visceralFat,
      'skeletalMuscle': skeletalMuscle,
      'physicalAge': physicalAge,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
