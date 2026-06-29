import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_model.dart';
import '../models/member_model.dart';
import '../services/fitdays_service.dart';
import '../services/member_service.dart';
import '../services/health_service.dart';
import '../services/streak_service.dart';
import '../theme/app_theme.dart';
import 'add_member_screen.dart';

/// Health status levels
enum HealthLevel { low, thin, standard, overweight, severelyOverweight, tooHigh, excellent }

/// Range definition for a metric segment
class MetricRange {
  final String label;
  final double? minValue;
  final double? maxValue;
  final Color color;
  final HealthLevel level;

  const MetricRange({
    required this.label,
    this.minValue,
    this.maxValue,
    required this.color,
    required this.level,
  });
}

/// Body index metric definition
class BodyIndexMetric {
  final String id;
  final String name;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final String description;
  final List<MetricRange> ranges;
  final double? Function() getValue;
  final double scaleMin;
  final double scaleMax;

  const BodyIndexMetric({
    required this.id,
    required this.name,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.description,
    required this.ranges,
    required this.getValue,
    required this.scaleMin,
    required this.scaleMax,
  });

  /// Get the current health level based on value
  HealthLevel? getHealthLevel(double? value) {
    if (value == null) return null;
    for (final range in ranges) {
      final min = range.minValue ?? double.negativeInfinity;
      final max = range.maxValue ?? double.infinity;
      if (value >= min && value < max) {
        return range.level;
      }
    }
    return null;
  }

  /// Get color for the current value
  Color getStatusColor(double? value) {
    if (value == null) return Colors.grey;
    for (final range in ranges) {
      final min = range.minValue ?? double.negativeInfinity;
      final max = range.maxValue ?? double.infinity;
      if (value >= min && value < max) {
        return range.color;
      }
    }
    return Colors.grey;
  }

  /// Get label for the current value
  String getStatusLabel(double? value) {
    if (value == null) return '--';
    for (final range in ranges) {
      final min = range.minValue ?? double.negativeInfinity;
      final max = range.maxValue ?? double.infinity;
      if (value >= min && value < max) {
        return range.label;
      }
    }
    return '--';
  }
}

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
  final MemberService _memberService = MemberService();
  
  WeightMeasurement? _latestMeasurement;
  WeightMeasurement? _compareMeasurement;
  Member? _activeMember;
  List<Member> _members = [];
  // True while switching members + re-initialising the SDK. Readings that arrive
  // during this window must NOT be saved — the SDK still holds the previous
  // member's profile, so body composition would be wrong for the new member.
  bool _switchingMember = false;
  bool _isConnected = false;
  bool _isLoading = true;
  StreamSubscription? _weightSub;
  StreamSubscription? _connectionSub;
  
  /// Get all body index metrics with their ranges based on user profile
  List<BodyIndexMetric> get _bodyIndexMetrics {
    final isMale = _activeMember?.gender == Gender.male;
    final age = _activeMember?.age ?? 25;
    
    return [
      BodyIndexMetric(
        id: 'bmi',
        name: 'BMI',
        unit: '',
        icon: Icons.monitor_weight_outlined,
        iconColor: Colors.blue,
        description: 'Body Mass Index (BMI) is a measure of your fitness level based on both your height and weight. This is calculated as weight (kg) divided by height (m²). The higher the BMI, the more likely you are to develop associated health problems though this is not a complete view of health and fitness.',
        scaleMin: 10,
        scaleMax: 35,
        getValue: () => _latestMeasurement?.bmi,
        ranges: [
          MetricRange(label: 'Thin', minValue: 0, maxValue: 18.5, color: const Color(0xFF4FC3F7), level: HealthLevel.thin),
          MetricRange(label: 'Standard', minValue: 18.5, maxValue: 25.0, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Overweight', minValue: 25.0, maxValue: 27.0, color: const Color(0xFFFFB74D), level: HealthLevel.overweight),
          MetricRange(label: 'Severely overweight', minValue: 27.0, maxValue: 100, color: const Color(0xFFE57373), level: HealthLevel.severelyOverweight),
        ],
      ),
      BodyIndexMetric(
        id: 'bodyFat',
        name: 'Body Fat',
        unit: '%',
        icon: Icons.fitness_center,
        iconColor: Colors.orange,
        description: 'Body Fat Percentage (BFP) is a percentage measurement of your fitness level based only on your weight. This is calculated as the body fat weight divided by the total body weight. The higher the body fat percentage, the more likely you are to develop associated health problems though this is not a complete view of health and fitness.',
        scaleMin: 0,
        scaleMax: 40,
        getValue: () => _latestMeasurement?.bodyFat,
        ranges: isMale ? [
          MetricRange(label: 'Thin', minValue: 0, maxValue: 10, color: const Color(0xFF4FC3F7), level: HealthLevel.thin),
          MetricRange(label: 'Standard', minValue: 10, maxValue: 20, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Overweight', minValue: 20, maxValue: 25, color: const Color(0xFFFFB74D), level: HealthLevel.overweight),
          MetricRange(label: 'Severely overweight', minValue: 25, maxValue: 100, color: const Color(0xFFE57373), level: HealthLevel.severelyOverweight),
        ] : [
          MetricRange(label: 'Thin', minValue: 0, maxValue: 18, color: const Color(0xFF4FC3F7), level: HealthLevel.thin),
          MetricRange(label: 'Standard', minValue: 18, maxValue: 28, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Overweight', minValue: 28, maxValue: 32, color: const Color(0xFFFFB74D), level: HealthLevel.overweight),
          MetricRange(label: 'Severely overweight', minValue: 32, maxValue: 100, color: const Color(0xFFE57373), level: HealthLevel.severelyOverweight),
        ],
      ),
      BodyIndexMetric(
        id: 'muscleRate',
        name: 'Muscle Rate',
        unit: '%',
        icon: Icons.sports_gymnastics,
        iconColor: Colors.teal,
        description: 'Muscle Rate represents the percentage of your body weight that is muscle. A higher muscle rate indicates better physical fitness and metabolic health. Regular exercise, especially strength training, can help increase muscle rate.',
        scaleMin: 20,
        scaleMax: 60,
        getValue: () => _latestMeasurement?.muscle,
        ranges: isMale ? [
          MetricRange(label: 'Low', minValue: 0, maxValue: 33, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 33, maxValue: 39, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 39, maxValue: 100, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ] : [
          MetricRange(label: 'Low', minValue: 0, maxValue: 25, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 25, maxValue: 30, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 30, maxValue: 100, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ],
      ),
      BodyIndexMetric(
        id: 'leanBodyMass',
        name: 'Lean Body Mass',
        unit: 'kg',
        icon: Icons.accessibility_new,
        iconColor: Colors.purple,
        description: 'Lean Body Mass (LBM) is the weight of everything in your body except fat. This includes muscles, bones, organs, skin, and body water. It is an important indicator for understanding your overall body composition.',
        scaleMin: 30,
        scaleMax: 80,
        getValue: () => _calculateLeanBodyMass(),
        ranges: isMale ? [
          MetricRange(label: 'Low', minValue: 0, maxValue: 50, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 50, maxValue: 65, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'High', minValue: 65, maxValue: 200, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ] : [
          MetricRange(label: 'Low', minValue: 0, maxValue: 38, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 38, maxValue: 50, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'High', minValue: 50, maxValue: 200, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ],
      ),
      BodyIndexMetric(
        id: 'subcutaneousFat',
        name: 'Subcutaneous Fat',
        unit: '%',
        icon: Icons.layers,
        iconColor: Colors.amber,
        description: 'Subcutaneous fat is the fat stored directly under your skin. While some subcutaneous fat is normal and healthy, too much can lead to health issues. This type of fat can be reduced through diet and exercise.',
        scaleMin: 0,
        scaleMax: 30,
        getValue: () => _latestMeasurement?.subcutaneousFat,
        ranges: isMale ? [
          MetricRange(label: 'Low', minValue: 0, maxValue: 8.6, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 8.6, maxValue: 16.7, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'High', minValue: 16.7, maxValue: 20.7, color: const Color(0xFFFFB74D), level: HealthLevel.overweight),
          MetricRange(label: 'Very High', minValue: 20.7, maxValue: 100, color: const Color(0xFFE57373), level: HealthLevel.severelyOverweight),
        ] : [
          MetricRange(label: 'Low', minValue: 0, maxValue: 18.5, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 18.5, maxValue: 26.7, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'High', minValue: 26.7, maxValue: 30.7, color: const Color(0xFFFFB74D), level: HealthLevel.overweight),
          MetricRange(label: 'Very High', minValue: 30.7, maxValue: 100, color: const Color(0xFFE57373), level: HealthLevel.severelyOverweight),
        ],
      ),
      BodyIndexMetric(
        id: 'visceralFat',
        name: 'Visceral Fat',
        unit: '',
        icon: Icons.local_fire_department,
        iconColor: Colors.red,
        description: 'Visceral Fat is a type of body fat that\'s stored within the abdominal cavity. The more visceral fat your body carries, the more likely you are to develop associated health problems though this is not a complete view of health and fitness.',
        scaleMin: 0,
        scaleMax: 20,
        getValue: () => _latestMeasurement?.visceralFat,
        ranges: [
          MetricRange(label: 'Standard', minValue: 0, maxValue: 10, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Too High', minValue: 10, maxValue: 100, color: const Color(0xFFE57373), level: HealthLevel.tooHigh),
        ],
      ),
      BodyIndexMetric(
        id: 'bodyWater',
        name: 'Body Water',
        unit: '%',
        icon: Icons.water_drop,
        iconColor: Colors.lightBlue,
        description: 'Body Water percentage is the total amount of fluid in the body expressed as a percentage of total body weight. Water plays a vital role in many of the body\'s processes, including temperature regulation, nutrient transport, and waste removal.',
        scaleMin: 40,
        scaleMax: 70,
        getValue: () => _latestMeasurement?.water,
        ranges: isMale ? [
          MetricRange(label: 'Low', minValue: 0, maxValue: 55, color: const Color(0xFFFFB74D), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 55, maxValue: 65, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 65, maxValue: 100, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ] : [
          MetricRange(label: 'Low', minValue: 0, maxValue: 45, color: const Color(0xFFFFB74D), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 45, maxValue: 60, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 60, maxValue: 100, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ],
      ),
      BodyIndexMetric(
        id: 'skeletalMuscle',
        name: 'Skeletal Muscle',
        unit: '%',
        icon: Icons.directions_run,
        iconColor: Colors.green,
        description: 'Skeletal Muscle is the type of muscle attached to bones that allows voluntary movement. Higher skeletal muscle mass is associated with better metabolic health, improved physical performance, and reduced risk of injury.',
        scaleMin: 20,
        scaleMax: 50,
        getValue: () => _latestMeasurement?.skeletalMuscle,
        ranges: isMale ? [
          MetricRange(label: 'Low', minValue: 0, maxValue: 40, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 40, maxValue: 60, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 60, maxValue: 100, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ] : [
          MetricRange(label: 'Low', minValue: 0, maxValue: 30, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 30, maxValue: 40, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 40, maxValue: 100, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ],
      ),
      BodyIndexMetric(
        id: 'muscleMass',
        name: 'Muscle Mass',
        unit: 'kg',
        icon: Icons.fitness_center,
        iconColor: Colors.indigo,
        description: 'Muscle Mass is the total weight of muscle tissue in your body. Higher muscle mass contributes to a higher basal metabolic rate and better overall physical health. It can be improved through resistance training.',
        scaleMin: 20,
        scaleMax: 60,
        getValue: () => _calculateMuscleMass(),
        ranges: isMale ? [
          MetricRange(label: 'Low', minValue: 0, maxValue: 32, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 32, maxValue: 40, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 40, maxValue: 200, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ] : [
          MetricRange(label: 'Low', minValue: 0, maxValue: 22, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 22, maxValue: 28, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 28, maxValue: 200, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ],
      ),
      BodyIndexMetric(
        id: 'boneMass',
        name: 'Bone Mass',
        unit: 'kg',
        icon: Icons.account_balance,
        iconColor: Colors.brown,
        description: 'Bone Mass is the estimated weight of bone mineral in your body. Healthy bone mass is crucial for overall skeletal health and helps prevent conditions like osteoporosis. Calcium-rich diet and weight-bearing exercises support bone health.',
        scaleMin: 1,
        scaleMax: 5,
        getValue: () => _latestMeasurement?.boneMass,
        ranges: isMale ? [
          MetricRange(label: 'Low', minValue: 0, maxValue: 2.5, color: const Color(0xFFFFB74D), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 2.5, maxValue: 3.5, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 3.5, maxValue: 20, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ] : [
          MetricRange(label: 'Low', minValue: 0, maxValue: 1.8, color: const Color(0xFFFFB74D), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 1.8, maxValue: 2.5, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 2.5, maxValue: 20, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ],
      ),
      BodyIndexMetric(
        id: 'protein',
        name: 'Protein',
        unit: '%',
        icon: Icons.egg,
        iconColor: Colors.deepOrange,
        description: 'Protein percentage indicates the proportion of your body weight made up of protein. Proteins are essential for building and repairing tissues, and a healthy protein level supports muscle maintenance and immune function.',
        scaleMin: 10,
        scaleMax: 25,
        getValue: () => _latestMeasurement?.protein,
        ranges: [
          MetricRange(label: 'Low', minValue: 0, maxValue: 16, color: const Color(0xFFFFB74D), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 16, maxValue: 20, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 20, maxValue: 100, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ],
      ),
      BodyIndexMetric(
        id: 'bmr',
        name: 'BMR',
        unit: 'kcal',
        icon: Icons.local_fire_department_outlined,
        iconColor: Colors.pink,
        description: 'Basal Metabolic Rate (BMR) is the minimum level of energy your body needs to function effectively while at rest. Individuals who exercise regularly tend to have higher BMR than people that are less active.',
        scaleMin: 1000,
        scaleMax: 2500,
        getValue: () => _latestMeasurement?.bmr?.toDouble(),
        ranges: _getBmrRanges(isMale, age),
      ),
      BodyIndexMetric(
        id: 'bodyAge',
        name: 'Body Age',
        unit: '',
        icon: Icons.cake,
        iconColor: Colors.cyan,
        description: 'Body Age is an estimation of your overall health age based on your body composition measurements. A body age lower than your actual age indicates good fitness, while a higher body age suggests room for improvement.',
        scaleMin: 15,
        scaleMax: 80,
        getValue: () => _latestMeasurement?.physicalAge?.toDouble(),
        ranges: [
          MetricRange(label: 'Excellent', minValue: 0, maxValue: age.toDouble() - 5, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
          MetricRange(label: 'Standard', minValue: age.toDouble() - 5, maxValue: age.toDouble() + 5, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Above Age', minValue: age.toDouble() + 5, maxValue: 200, color: const Color(0xFFFFB74D), level: HealthLevel.overweight),
        ],
      ),
      BodyIndexMetric(
        id: 'fatMass',
        name: 'Fat Mass',
        unit: 'kg',
        icon: Icons.pie_chart,
        iconColor: Colors.orange,
        description: 'Fat Mass is the total weight of fat tissue in your body. While some fat is essential for health, excess fat mass can increase health risks. A balanced diet and regular exercise help maintain healthy fat levels.',
        scaleMin: 5,
        scaleMax: 40,
        getValue: () => _calculateFatMass(),
        ranges: isMale ? [
          MetricRange(label: 'Low', minValue: 0, maxValue: 8, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 8, maxValue: 15, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'High', minValue: 15, maxValue: 20, color: const Color(0xFFFFB74D), level: HealthLevel.overweight),
          MetricRange(label: 'Very High', minValue: 20, maxValue: 200, color: const Color(0xFFE57373), level: HealthLevel.severelyOverweight),
        ] : [
          MetricRange(label: 'Low', minValue: 0, maxValue: 13, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 13, maxValue: 20, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'High', minValue: 20, maxValue: 27, color: const Color(0xFFFFB74D), level: HealthLevel.overweight),
          MetricRange(label: 'Very High', minValue: 27, maxValue: 200, color: const Color(0xFFE57373), level: HealthLevel.severelyOverweight),
        ],
      ),
      BodyIndexMetric(
        id: 'waterWeight',
        name: 'Water Weight',
        unit: 'kg',
        icon: Icons.water,
        iconColor: Colors.blue,
        description: 'Water Weight is the total weight of water in your body. The body needs adequate water to function properly. Variations in water weight can occur due to hydration levels, diet, and physical activity.',
        scaleMin: 20,
        scaleMax: 50,
        getValue: () => _calculateWaterWeight(),
        ranges: [
          MetricRange(label: 'Low', minValue: 0, maxValue: 30, color: const Color(0xFFFFB74D), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 30, maxValue: 45, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'High', minValue: 45, maxValue: 200, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ],
      ),
      BodyIndexMetric(
        id: 'proteinMass',
        name: 'Protein Mass',
        unit: 'kg',
        icon: Icons.restaurant,
        iconColor: Colors.amber,
        description: 'Protein Mass is the total weight of protein in your body. Adequate protein is essential for muscle building, tissue repair, and enzyme production. A protein-rich diet supports healthy protein mass levels.',
        scaleMin: 5,
        scaleMax: 20,
        getValue: () => _calculateProteinMass(),
        ranges: [
          MetricRange(label: 'Low', minValue: 0, maxValue: 8, color: const Color(0xFFFFB74D), level: HealthLevel.low),
          MetricRange(label: 'Standard', minValue: 8, maxValue: 12, color: const Color(0xFF81C784), level: HealthLevel.standard),
          MetricRange(label: 'Excellent', minValue: 12, maxValue: 100, color: const Color(0xFF4DB6AC), level: HealthLevel.excellent),
        ],
      ),
      BodyIndexMetric(
        id: 'idealWeight',
        name: 'Ideal Body Weight',
        unit: 'kg',
        icon: Icons.trending_up,
        iconColor: Colors.green,
        description: 'Ideal Body Weight is an estimated healthy weight based on your height using a BMI of 22. This is a general guideline and actual healthy weight can vary based on individual factors like muscle mass and body composition.',
        scaleMin: 40,
        scaleMax: 100,
        getValue: () => _calculateIdealWeight(),
        ranges: [
          MetricRange(label: 'Reference', minValue: 0, maxValue: 200, color: const Color(0xFF81C784), level: HealthLevel.standard),
        ],
      ),
    ];
  }
  
  /// Get BMR ranges based on gender and age
  List<MetricRange> _getBmrRanges(bool isMale, int age) {
    double threshold;
    if (isMale) {
      if (age < 30) threshold = 1600;
      else if (age < 50) threshold = 1500;
      else threshold = 1350;
    } else {
      if (age < 30) threshold = 1300;
      else if (age < 50) threshold = 1200;
      else threshold = 1100;
    }
    return [
      MetricRange(label: 'Low', minValue: 0, maxValue: threshold, color: const Color(0xFF4FC3F7), level: HealthLevel.low),
      MetricRange(label: 'Excellent', minValue: threshold, maxValue: 10000, color: const Color(0xFF81C784), level: HealthLevel.excellent),
    ];
  }

  @override
  void initState() {
    super.initState();
    _setupConnectionListener(); // set up connection state listener immediately
    _loadDataThenListenWeight(); // wait for SDK init before listening to weight
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _members = await _memberService.getMembers();
      _activeMember = await _memberService.getActiveMember();
      
      // Create default member if none exist
      if (_members.isEmpty) {
        _activeMember = await _memberService.createDefaultMember();
        _members = [_activeMember!];
      }
      
      // Update SDK with current user info
      if (_activeMember != null) {
        // Clean up duplicates first
        await _memberService.removeDuplicates(_activeMember!.id);
        
        await widget.fitDaysService.initializeSDK(
          age: _activeMember!.age,
          height: _activeMember!.heightCm,
          sex: _activeMember!.gender.sdkSexType,
        );

        // Load latest measurement for offline access
        final measurements = await _memberService.getMeasurements(_activeMember!.id, limit: 2);
        if (measurements.isNotEmpty) {
          _latestMeasurement = WeightMeasurement.fromBodyMeasurement(measurements.first);
          if (measurements.length > 1) {
            _compareMeasurement = WeightMeasurement.fromBodyMeasurement(measurements[1]);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Set up connection state listener immediately so we track connect/disconnect
  /// even while _loadData is still running.
  void _setupConnectionListener() {
    _connectionSub = widget.fitDaysService.connectionStateStream.listen((state) {
      final deviceMac = state['macAddress'] ?? state['deviceId'];
      if (mounted && deviceMac == widget.connectedDevice.macAddress) {
        setState(() {
          _isConnected = state['state'] == 'connected';
        });
      }
    });
  }

  /// Wait for _loadData (which calls initializeSDK) to complete before
  /// subscribing to weight events.  This ensures the native SDK has the
  /// user's age/height/sex before BIA data arrives, so body composition
  /// is calculated correctly.
  Future<void> _loadDataThenListenWeight() async {
    await _loadData();
    if (!mounted) return;
    _weightSub = widget.fitDaysService.weightDataStream.listen((measurement) {
      if (!mounted) return;

      // Only accept body fat scale readings.
      // Kitchen scale readings are tagged kitchenScale by FitDaysService
      // (or weigh < 10 kg which no human body does).
      if (measurement.source == WeightSource.kitchenScale) return;

      setState(() {
        _latestMeasurement = measurement;
        _isConnected       = true;
      });

      // Save only stable plausible adult readings that carry body composition.
      // This prevents a weight-only ramp-up reading (or a stale kitchen-scale
      // reading that slipped through) from being saved as a body measurement.
      if (measurement.isStabilized &&
          measurement.weight >= 20.0 &&
          _activeMember != null &&
          !_switchingMember && // don't save while the SDK is mid-profile-switch
          measurement.hasBodyComposition) {
        _saveMeasurement(measurement);
      }
    });
  }

  @override
  void dispose() {
    _weightSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  Future<void> _saveMeasurement(WeightMeasurement measurement) async {
    if (_activeMember == null) return;

    final bodyMeasurement = BodyMeasurement(
      id: MemberService.generateId(),
      memberId: _activeMember!.id,
      timestamp: DateTime.now(),
      weightKg: measurement.weight,
      bmi: measurement.bmi,
      bodyFatPercent: measurement.bodyFat,
      subcutaneousFatPercent: measurement.subcutaneousFat,
      muscleRatePercent: measurement.muscle,
      bodyWaterPercent: measurement.water,
      boneMassKg: measurement.boneMass,
      proteinPercent: measurement.protein,
      bmr: measurement.bmr?.toInt(),
      visceralFat: measurement.visceralFat,
      skeletalMusclePercent: measurement.skeletalMuscle,
      bodyAge: measurement.physicalAge?.toInt(),
    );

    await _memberService.addMeasurement(bodyMeasurement);

    // Update the home-screen "Weight" stat, which reads this key.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('latest_weight', measurement.weight);

    // Push to Apple Health / Health Connect (silent — never blocks UI)
    HealthService().syncScaleReading(measurement);

    // Recording a body measurement keeps the daily streak alive.
    await StreakService.recordActivity();
  }

  /// BMI from height in member profile — no BIA needed
  double _calcBmi(double weightKg) {
    if (_activeMember == null) return 0;
    final heightM = _activeMember!.heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  /// Mifflin-St Jeor BMR estimate — no BIA needed
  int _calcBmr(double weightKg) {
    if (_activeMember == null) return 0;
    final h = _activeMember!.heightCm.toDouble();
    final a = _activeMember!.age.toDouble();
    final base = (10 * weightKg) + (6.25 * h) - (5 * a);
    return (_activeMember!.gender == Gender.male ? base + 5 : base - 161).round();
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXxl)),
        title: Text('Log Weight Manually',
            style: AppTheme.headingSM.copyWith(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppTheme.numericMD.copyWith(fontSize: 28),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0.0',
                hintStyle: AppTheme.numericMD.copyWith(
                    fontSize: 28, color: AppTheme.textTertiary),
                suffixText: 'kg',
                suffixStyle: AppTheme.bodyLG,
                filled: true,
                fillColor: AppTheme.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 13, color: AppTheme.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'BMI & BMR are calculated automatically. Body fat & composition require the smart scale.',
                  style: AppTheme.bodySM,
                ),
              ),
            ]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTheme.bodyMD),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lime,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
            ),
            onPressed: () async {
              final weight = double.tryParse(controller.text.trim());
              Navigator.pop(ctx);
              if (weight != null && weight > 0 && weight < 500) {
                await _saveManualWeight(weight);
              }
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveManualWeight(double weightKg) async {
    if (_activeMember == null) return;
    final bmi = _calcBmi(weightKg);
    final bmr = _calcBmr(weightKg);

    final bodyMeasurement = BodyMeasurement(
      id: MemberService.generateId(),
      memberId: _activeMember!.id,
      timestamp: DateTime.now(),
      weightKg: weightKg,
      bmi: bmi > 0 ? bmi : null,
      bmr: bmr > 0 ? bmr : null,
      // BIA-based fields left null — require smart scale
    );

    await _memberService.addMeasurement(bodyMeasurement);

    // Update the home-screen "Weight" stat, which reads this key.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('latest_weight', weightKg);

    // Logging a weight keeps the daily streak alive.
    await StreakService.recordActivity();

    final measurements =
        await _memberService.getMeasurements(_activeMember!.id, limit: 2);
    if (mounted && measurements.isNotEmpty) {
      setState(() {
        _latestMeasurement =
            WeightMeasurement.fromBodyMeasurement(measurements.first);
        if (measurements.length > 1) {
          _compareMeasurement =
              WeightMeasurement.fromBodyMeasurement(measurements[1]);
        }
      });
    }
  }

  /// Switches the active member atomically: blocks saving, clears the previous
  /// member's reading, re-initialises the SDK with the new member's profile, then
  /// loads the new member's history. Prevents a reading from being saved to the
  /// wrong profile or with another member's body-composition math.
  Future<void> _switchToMember(Member member) async {
    setState(() {
      _switchingMember = true;
      _activeMember = member;
      // Drop the previous member's reading so it can't be attributed here.
      _latestMeasurement = null;
      _compareMeasurement = null;
    });

    await _memberService.setActiveMember(member.id);
    await widget.fitDaysService.initializeSDK(
      age: member.age,
      height: member.heightCm,
      sex: member.gender.sdkSexType,
    );

    // Load the new member's most recent measurements for the screen.
    final measurements =
        await _memberService.getMeasurements(member.id, limit: 2);
    if (!mounted) return;
    setState(() {
      if (measurements.isNotEmpty) {
        _latestMeasurement = WeightMeasurement.fromBodyMeasurement(measurements.first);
        if (measurements.length > 1) {
          _compareMeasurement = WeightMeasurement.fromBodyMeasurement(measurements[1]);
        }
      }
      _switchingMember = false;
    });
  }

  void _showMemberSelector() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.surface1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXxl)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Switch Member', style: AppTheme.headingSM),
            ),
            ..._members.map((member) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.lime.withOpacity(0.15),
                child: Text(
                  member.nickname.isNotEmpty
                      ? member.nickname[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppTheme.lime, fontWeight: FontWeight.w900),
                ),
              ),
              title: Text(member.nickname, style: AppTheme.headingSM.copyWith(fontSize: 14)),
              trailing: _activeMember?.id == member.id
                  ? Container(
                      width: 24, height: 24,
                      decoration: const BoxDecoration(
                          color: AppTheme.lime, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.black, size: 15),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                _switchToMember(member);
              },
            )),
            Divider(height: 1, color: Colors.white.withOpacity(0.06)),
            ListTile(
              leading: const Icon(Icons.person_add_outlined,
                  color: AppTheme.textSecondary),
              title: Text('Add Member', style: AppTheme.bodyLG),
              onTap: () {
                Navigator.pop(context);
                _showMemberManagement();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMemberManagement() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMemberScreen()),
    );
    if (result != null && result is Member) {
      // Set the newly created member as active so the SDK uses their profile
      await _memberService.setActiveMember(result.id);
    }
    if (result != null) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.lime)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildWeightCard(),
                    _buildConnectionStatus(),
                    _buildComparedSection(),
                    _buildBodyIndexSection(),
                    _buildDisclaimerSection(),
                    _buildTrendSection(),
                    // _buildBabyPetModeCard() removed
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: AppTheme.bg,
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _showMemberSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(children: [
              Text(_activeMember?.nickname ?? 'User',
                  style: AppTheme.labelLG.copyWith(color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.surface3,
                child: Text(
                  (_activeMember?.nickname.isNotEmpty == true)
                      ? _activeMember!.nickname[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                      color: AppTheme.lime,
                      fontSize: 13,
                      fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded,
                  color: AppTheme.textSecondary, size: 16),
            ]),
          ),
        ),
        const SizedBox(width: 8),
      ]),
    );
  }

  Widget _buildWeightCard() {
    final weight    = _latestMeasurement?.weight ?? 0.0;
    final timestamp = _latestMeasurement?.timestamp ?? DateTime.now();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.surface1, AppTheme.surface2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              weight > 0 ? weight.toStringAsFixed(2) : '--',
              style: AppTheme.numericXL.copyWith(
                fontSize: 64,
                color: weight > 0 ? AppTheme.lime : AppTheme.textTertiary,
                letterSpacing: -2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 6),
              child: Text('kg',
                  style: AppTheme.numericMD.copyWith(
                      color: AppTheme.textSecondary, fontSize: 22)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          weight > 0
              ? DateFormat('MMM d, yyyy · HH:mm').format(timestamp)
              : 'Step on the scale to measure',
          style: AppTheme.bodyMD,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showManualEntryDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.surface3,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_outlined,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text('Log manually',
                    style: AppTheme.labelMD.copyWith(
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
        if (_latestMeasurement != null && weight > 0) ...[
          const SizedBox(height: 16),
          // Quick metrics strip — always show if we have a measurement
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _quickStat('BMI',
                  _latestMeasurement!.bmi?.toStringAsFixed(1), '',
                  AppTheme.lime),
              _quickStat('Body Fat',
                  _latestMeasurement!.bodyFat?.toStringAsFixed(1), '%',
                  const Color(0xFFFF8C42)),
              _quickStat('Muscle',
                  _latestMeasurement!.muscle?.toStringAsFixed(1), '%',
                  const Color(0xFF4ECDC4)),
              _quickStat('Water',
                  _latestMeasurement!.water?.toStringAsFixed(1), '%',
                  const Color(0xFF3B9EFF)),
            ],
          ),
        ],
      ]),
    );
  }

  Widget _quickStat(String label, String? value, String unit, Color color) {
    return Column(children: [
      Text(
        value != null ? '$value$unit' : '--',
        style: AppTheme.numericMD.copyWith(color: color, fontSize: 18),
      ),
      const SizedBox(height: 3),
      Text(label, style: AppTheme.labelSM),
    ]);
  }

  Widget _buildConnectionStatus() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 7, height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isConnected ? AppTheme.lime : AppTheme.textTertiary,
            boxShadow: _isConnected
                ? [BoxShadow(
                      color: AppTheme.lime.withOpacity(0.6), blurRadius: 6)]
                : [],
          ),
        ),
        const SizedBox(width: 7),
        Text(
          _isConnected
              ? '${widget.connectedDevice.name} · Connected'
              : 'Reconnecting…',
          style: AppTheme.bodyMD.copyWith(
            color: _isConnected ? AppTheme.lime : AppTheme.textTertiary,
            fontWeight:
                _isConnected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ]),
    );
  }

  Widget _buildComparedSection() {
    return GestureDetector(
      onTap: _showComparisonSelector,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Compared', style: AppTheme.headingSM),
                Row(
                  children: [
                    Text(
                      _compareMeasurement != null
                          ? DateFormat('MMM d · HH:mm').format(_compareMeasurement!.timestamp)
                          : 'Select record',
                      style: AppTheme.bodyMD,
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppTheme.textTertiary),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildCompareItem(
                  'Weight', 
                  _latestMeasurement?.weight, 
                  _compareMeasurement?.weight, 
                  'kg'
                ),
                _buildCompareItem(
                  'BMI', 
                  _latestMeasurement?.bmi, 
                  _compareMeasurement?.bmi, 
                  ''
                ),
                _buildCompareItem(
                  'Body Fat', 
                  _latestMeasurement?.bodyFat, 
                  _compareMeasurement?.bodyFat, 
                  '%'
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareItem(String label, double? current, double? previous, String unit) {
    String diffText = '--';
    Color diffColor = Colors.grey;
    IconData? diffIcon;

    if (current != null && previous != null) {
      final diff = current - previous;
      final absDiff = diff.abs();
      
      if (absDiff < 0.01) {
        diffText = '0.0';
        diffColor = Colors.grey;
      } else {
        diffText = '${diff > 0 ? '+' : '-'}${absDiff.toStringAsFixed(1)}'; // Changed to show sign
        // Usually lower is better for weight/fat, but context depends. 
        // Keeping it simple: Green for decrease, Red for increase for weight/fat? 
        // Or just neutral colors? The designs usually use specific colors.
        // Let's assume generic trend colors: 
        if (label == 'Muscle Rate') {
             diffColor = diff > 0 ? Colors.green : Colors.red;
        } else {
             // For weight/fat/BMI, usually decrease is "good" visually in these apps, 
             // but technically not always. Let's use neutral or arrow indicators.
             // Following the user's screenshot style if possible. 
             // Screenshot shows '4.05 kg' with down arrow.
             diffColor = Colors.black87; // The value itself
        }
        
        diffIcon = diff > 0 ? Icons.arrow_upward : Icons.arrow_downward;
      }
      
      // Override formatting to match screenshot: Value Unit
      if (unit.isNotEmpty) {
          diffText = '$diffText $unit';
      }
    } else if (current != null) {
         diffText = '${current.toStringAsFixed(1)} $unit';
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            label, // e.g. "Weight" (The screenshot shows "- Weight")
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
                if (diffIcon != null && current != null && previous != null)
                   Icon(diffIcon, size: 12, color:  (current - previous) > 0 ? Colors.red : Colors.green), // Assuming weight control context
                
                Text(
                    diffText.replaceAll('+', '').replaceAll('-', ''), // Value only
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                if (unit.isNotEmpty && current != null && previous != null) ...[
                     const SizedBox(width: 2),
                     Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showComparisonSelector() async {
    if (_activeMember == null) return;

    final measurements = await _memberService.getMeasurements(_activeMember!.id);
    
    // Sort by new to old
    // measurements are already sorted by member_service.dart

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXxl)),
        ),
        child: Column(
          children: [
            // Handle
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
                Text('Compare Record', style: AppTheme.headingSM),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary, size: 22),
                ),
              ]),
            ),
            Divider(height: 1, color: Colors.white.withOpacity(0.06)),
            Expanded(
              child: measurements.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history_rounded,
                                color: AppTheme.textTertiary, size: 40),
                            const SizedBox(height: 12),
                            Text('No past measurements',
                                style: AppTheme.bodyMD),
                          ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: measurements.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final m = measurements[index];
                        final isSelected =
                            _compareMeasurement?.timestamp == m.timestamp;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _compareMeasurement =
                                  WeightMeasurement.fromBodyMeasurement(m);
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.lime.withOpacity(0.08)
                                  : AppTheme.surface2,
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLg),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.lime.withOpacity(0.4)
                                    : Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Row(children: [
                              Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('HH:mm')
                                          .format(m.timestamp),
                                      style: AppTheme.numericMD
                                          .copyWith(fontSize: 20),
                                    ),
                                    Text(_getDateLabel(m.timestamp),
                                        style: AppTheme.bodyMD),
                                  ]),
                              const Spacer(),
                              Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text('Weight',
                                        style: AppTheme.labelMD.copyWith(
                                            color:
                                                AppTheme.textTertiary)),
                                    Text(
                                      '${m.weightKg.toStringAsFixed(1)} kg',
                                      style: AppTheme.labelLG.copyWith(
                                          color: isSelected
                                              ? AppTheme.lime
                                              : AppTheme.textPrimary),
                                    ),
                                  ]),
                              const SizedBox(width: 16),
                              Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text('Body Fat',
                                        style: AppTheme.labelMD.copyWith(
                                            color:
                                                AppTheme.textTertiary)),
                                    Text(
                                      '${m.bodyFatPercent?.toStringAsFixed(1) ?? '--'} %',
                                      style: AppTheme.labelLG.copyWith(
                                          color: AppTheme.textPrimary),
                                    ),
                                  ]),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDateLabel(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (date == today) {
      return 'Today';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }



  Widget _buildBodyIndexSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Body Index', style: AppTheme.headingSM),
          ),
          ..._bodyIndexMetrics.asMap().entries.map((e) {
            final isLast = e.key == _bodyIndexMetrics.length - 1;
            return Column(children: [
              _buildBodyIndexRow(e.value),
              if (!isLast)
                Divider(height: 1,
                    color: Colors.white.withOpacity(0.04), indent: 56),
            ]);
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBodyIndexRow(BodyIndexMetric metric) {
    final value       = metric.getValue();
    final statusColor = metric.getStatusColor(value);
    final valStr = value != null
        ? '${value.toStringAsFixed(metric.unit == 'kcal' || metric.id == 'bodyAge' ? 0 : 1)}${metric.unit.isNotEmpty ? ' ${metric.unit}' : ''}'
        : '--';

    return InkWell(
      onTap: () => _showMetricDetailSheet(metric),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: metric.iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(metric.icon, color: metric.iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(metric.name,
                style: AppTheme.bodyLG.copyWith(color: AppTheme.textPrimary)),
          ),
          Text(valStr,
              style: AppTheme.labelLG.copyWith(
                  color: value != null
                      ? AppTheme.textPrimary
                      : AppTheme.textTertiary)),
          const SizedBox(width: 8),
          Container(
            width: 9, height: 9,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: AppTheme.textTertiary, size: 16),
        ]),
      ),
    );
  }

  void _showMetricDetailSheet(BodyIndexMetric metric) {
    final metrics = _bodyIndexMetrics;
    final initialIndex = metrics.indexWhere((m) => m.id == metric.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXxl)),
      ),
      builder: (context) => _MetricDetailSheet(
        metrics: metrics,
        initialIndex: initialIndex,
      ),
    );
  }

  Widget _buildDisclaimerSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded,
            color: AppTheme.textTertiary, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Not a medical device. Results cannot be used as medical diagnosis.',
            style: AppTheme.bodySM,
          ),
        ),
      ]),
    );
  }

  Widget _buildTrendSection() {
    if (_activeMember == null) return const SizedBox.shrink();
    return FutureBuilder<List<BodyMeasurement>>(
      future: _memberService.getMeasurements(
          _activeMember!.id, limit: 30),
      builder: (context, snap) {
        final measurements = snap.data ?? [];
        // Need at least 2 points for a line
        final hasTrend = measurements.length >= 2;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Weight Trend', style: AppTheme.headingSM),
                  Text(
                    hasTrend ? 'Last ${measurements.length} records' : '',
                    style: AppTheme.labelMD.copyWith(
                        color: AppTheme.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!hasTrend)
                SizedBox(
                  height: 120,
                  child: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.show_chart_rounded,
                              color: AppTheme.textTertiary, size: 36),
                          const SizedBox(height: 8),
                          Text('Sync your scale to see trends',
                              style: AppTheme.bodyMD),
                        ]),
                  ),
                )
              else
                _WeightChart(measurements: measurements),
            ],
          ),
        );
      },
    );
  }



  Widget _buildTargetCard() {
    final current = _latestMeasurement?.weight;
    return FutureBuilder<Map<String, dynamic>?>(
      future: SharedPreferences.getInstance().then((p) {
        final t = p.getDouble('user_target_weight_kg');
        final s = p.getDouble('user_weight_kg');      // starting weight
        final g = p.getString('user_goal') ?? 'lose'; // 'lose' | 'maintain' | 'gain'
        if (t == null) return null;
        return {'target': t, 'start': s, 'goal': g};
      }),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface1,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Text('Complete onboarding to set your target weight.',
                style: AppTheme.bodyMD),
          );
        }

        final target  = snap.data!['target'] as double;
        final start   = snap.data!['start']  as double?;
        final goal    = snap.data!['goal']   as String;

        // Progress calculation depends on goal type
        double? progress;
        bool isReached = false;
        String progressLabel = '';

        if (current != null && current > 0) {
          final diff = (current - target).abs();
          switch (goal) {
            case 'lose':
              isReached = current <= target + 0.5;
              if (start != null && start > target) {
                progress = ((start - current) / (start - target)).clamp(0.0, 1.0);
              }
              progressLabel = isReached
                  ? '🎉 Goal reached!'
                  : '${(current - target).toStringAsFixed(1)} kg to go';
              break;
            case 'gain':
              isReached = current >= target - 0.5;
              if (start != null && target > start) {
                progress = ((current - start) / (target - start)).clamp(0.0, 1.0);
              }
              progressLabel = isReached
                  ? '🎉 Goal reached!'
                  : '${(target - current).toStringAsFixed(1)} kg to go';
              break;
            default: // maintain
              isReached = diff <= 1.0;
              progress  = isReached ? 1.0 : (1.0 - (diff / 5.0)).clamp(0.0, 1.0);
              progressLabel = isReached
                  ? '✅ Maintaining well!'
                  : '${diff.toStringAsFixed(1)} kg from target';
          }
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Target Weight', style: AppTheme.headingSM),
                const Icon(Icons.flag_outlined, color: AppTheme.lime, size: 18),
              ],
            ),
            const SizedBox(height: 14),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Current', style: AppTheme.labelMD.copyWith(color: AppTheme.textTertiary)),
                const SizedBox(height: 2),
                Text(
                  current != null && current > 0
                      ? '${current.toStringAsFixed(1)} kg'
                      : '--',
                  style: AppTheme.numericMD.copyWith(fontSize: 22),
                ),
              ]),
              const Spacer(),
              const Icon(Icons.arrow_forward_rounded,
                  color: AppTheme.textTertiary, size: 18),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Goal', style: AppTheme.labelMD.copyWith(color: AppTheme.textTertiary)),
                const SizedBox(height: 2),
                Text('${target.toStringAsFixed(1)} kg',
                    style: AppTheme.numericMD.copyWith(
                        fontSize: 22, color: AppTheme.lime)),
              ]),
            ]),
            if (progress != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.surface3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      isReached ? AppTheme.lime : const Color(0xFF4ECDC4)),
                  minHeight: 4,
                ),
              ),
              if (progressLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(progressLabel,
                    style: AppTheme.bodyMD.copyWith(
                        color: isReached ? AppTheme.lime : AppTheme.textSecondary)),
              ],
            ],
          ]),
        );
      },
    );
  }

  // Calculate derived values
  double? _calculateLeanBodyMass() {
    if (_latestMeasurement?.weight == null || _latestMeasurement?.bodyFat == null) return null;
    final weight = _latestMeasurement!.weight;
    final bodyFat = _latestMeasurement!.bodyFat!;
    return weight * (1 - bodyFat / 100);
  }

  double? _calculateMuscleMass() {
    if (_latestMeasurement?.weight == null || _latestMeasurement?.muscle == null) return null;
    return _latestMeasurement!.weight * _latestMeasurement!.muscle! / 100;
  }

  double? _calculateFatMass() {
    if (_latestMeasurement?.weight == null || _latestMeasurement?.bodyFat == null) return null;
    return _latestMeasurement!.weight * _latestMeasurement!.bodyFat! / 100;
  }

  double? _calculateWaterWeight() {
    if (_latestMeasurement?.weight == null || _latestMeasurement?.water == null) return null;
    return _latestMeasurement!.weight * _latestMeasurement!.water! / 100;
  }

  double? _calculateProteinMass() {
    if (_latestMeasurement?.weight == null || _latestMeasurement?.protein == null) return null;
    return _latestMeasurement!.weight * _latestMeasurement!.protein! / 100;
  }

  double? _calculateIdealWeight() {
    if (_activeMember == null) return null;
    final heightM = _activeMember!.heightCm / 100.0;
    // Using BMI 22 as ideal
    return 22 * heightM * heightM;
  }
}

/// Bottom sheet widget for showing metric details with scale
class _MetricDetailSheet extends StatefulWidget {
  final List<BodyIndexMetric> metrics;
  final int initialIndex;

  const _MetricDetailSheet({
    required this.metrics,
    required this.initialIndex,
  });

  @override
  State<_MetricDetailSheet> createState() => _MetricDetailSheetState();
}

class _MetricDetailSheetState extends State<_MetricDetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.metrics.length,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _pageController = PageController(initialPage: widget.initialIndex);
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _pageController.animateToPage(
          _tabController.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Tab bar
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.lime,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.lime,
          indicatorWeight: 2,
          dividerColor: Colors.white.withOpacity(0.06),
          tabs: widget.metrics.map((m) => Tab(text: m.name)).toList(),
        ),
        // Page content
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.metrics.length,
            onPageChanged: (index) => _tabController.animateTo(index),
            itemBuilder: (context, index) =>
                _buildMetricContent(widget.metrics[index]),
          ),
        ),
        // Close button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.lime,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.lime.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('Close',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.black)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildMetricContent(BodyIndexMetric metric) {
    final value = metric.getValue();
    final statusColor = metric.getStatusColor(value);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(children: [
        // Large value
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value != null
                  ? value.toStringAsFixed(
                      metric.unit == 'kcal' || metric.id == 'bodyAge' ? 0 : 1)
                  : '--',
              style: AppTheme.numericXL.copyWith(
                fontSize: 64,
                color: value != null ? statusColor : AppTheme.textTertiary,
                letterSpacing: -2,
              ),
            ),
            if (metric.unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 6),
                child: Text(metric.unit,
                    style: AppTheme.numericMD.copyWith(
                        color: AppTheme.textSecondary, fontSize: 22)),
              ),
          ],
        ),
        if (value != null) ...[
          const SizedBox(height: 4),
          Text(
            metric.getStatusLabel(value),
            style: AppTheme.labelLG.copyWith(color: statusColor),
          ),
        ],
        const SizedBox(height: 20),
        _buildScaleBar(metric, value),
        const SizedBox(height: 20),
        Divider(height: 1, color: Colors.white.withOpacity(0.06)),
        const SizedBox(height: 16),
        Text(
          metric.description,
          style: AppTheme.bodyMD.copyWith(height: 1.6),
          textAlign: TextAlign.left,
        ),
      ]),
    );
  }

  Widget _buildScaleBar(BodyIndexMetric metric, double? value) {
    final ranges = metric.ranges;
    if (ranges.isEmpty) return const SizedBox.shrink();
    
    // Calculate scale boundaries
    final scaleMin = metric.scaleMin;
    final scaleMax = metric.scaleMax;
    final scaleWidth = scaleMax - scaleMin;
    
    // Get key threshold values to show
    List<double> thresholds = [];
    for (int i = 0; i < ranges.length; i++) {
      if (ranges[i].minValue != null && ranges[i].minValue! > scaleMin && ranges[i].minValue! < scaleMax) {
        if (!thresholds.contains(ranges[i].minValue!)) {
          thresholds.add(ranges[i].minValue!);
        }
      }
    }
    thresholds.sort();
    
    // Calculate user position
    double? userPosition;
    if (value != null) {
      userPosition = ((value - scaleMin) / scaleWidth).clamp(0.0, 1.0);
    }
    
    return Column(
      children: [
        // Threshold values above scale
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: thresholds.map((t) => Text(
              t.toStringAsFixed(t == t.roundToDouble() ? 0 : 1),
              style: AppTheme.labelLG.copyWith(color: AppTheme.textSecondary),
            )).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Scale bar with marker
        SizedBox(
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Color segments
              Positioned.fill(
                child: Row(
                  children: ranges.map((range) {
                    final rangeMin = range.minValue ?? scaleMin;
                    final rangeMax = range.maxValue ?? scaleMax;
                    final clampedMin = rangeMin.clamp(scaleMin, scaleMax);
                    final clampedMax = rangeMax.clamp(scaleMin, scaleMax);
                    final segmentWidth = (clampedMax - clampedMin) / scaleWidth;
                    
                    if (segmentWidth <= 0) return const SizedBox.shrink();
                    
                    return Expanded(
                      flex: (segmentWidth * 100).round().clamp(1, 100),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: range.color,
                          borderRadius: BorderRadius.horizontal(
                            left: range == ranges.first ? const Radius.circular(4) : Radius.zero,
                            right: range == ranges.last ? const Radius.circular(4) : Radius.zero,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // User position marker
              if (userPosition != null)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final markerX = userPosition! * constraints.maxWidth;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: markerX - 25, // Centered (50px width)
                            width: 50,
                            bottom: 24, // Touch the bar top (40px stack - 16px to bar top)
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  value!.toStringAsFixed(metric.unit == 'kcal' || metric.id == 'bodyAge' ? 0 : 1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.lime,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                CustomPaint(
                                  size: const Size(12, 8),
                                  painter: _TrianglePainter(color: AppTheme.lime),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Range labels below scale
        Row(
          children: ranges.map((range) {
            final rangeMin = range.minValue ?? scaleMin;
            final rangeMax = range.maxValue ?? scaleMax;
            final clampedMin = rangeMin.clamp(scaleMin, scaleMax);
            final clampedMax = rangeMax.clamp(scaleMin, scaleMax);
            final segmentWidth = (clampedMax - clampedMin) / scaleWidth;
            
            if (segmentWidth <= 0) return const SizedBox.shrink();
            
            return Expanded(
              flex: (segmentWidth * 100).round().clamp(1, 100),
              child: Text(
                range.label,
                style: AppTheme.bodySM,
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Weight trend line chart ────────────────────────────────────────────────
class _WeightChart extends StatelessWidget {
  final List<BodyMeasurement> measurements;
  const _WeightChart({required this.measurements});

  @override
  Widget build(BuildContext context) {
    // Sort oldest → newest for left-to-right display
    final sorted = [...measurements]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final weights = sorted.map((m) => m.weightKg).toList();
    final minW = (weights.reduce((a, b) => a < b ? a : b) - 1).floorToDouble();
    final maxW = (weights.reduce((a, b) => a > b ? a : b) + 1).ceilToDouble();

    final spots = sorted.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.weightKg)).toList();

    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          minY: minW,
          maxY: maxW,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxW - minW) / 3,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withOpacity(0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: (maxW - minW) / 3,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(1),
                  style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: sorted.length > 6
                    ? (sorted.length / 4).floorToDouble()
                    : 1,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= sorted.length) {
                    return const SizedBox.shrink();
                  }
                  final d = sorted[idx].timestamp;
                  return Text(
                    '${d.day}/${d.month}',
                    style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppTheme.surface2,
              getTooltipItems: (spots) => spots.map((s) {
                final d = sorted[s.spotIndex].timestamp;
                return LineTooltipItem(
                  '${s.y.toStringAsFixed(1)} kg\n${d.day}/${d.month}',
                  const TextStyle(
                      color: AppTheme.lime,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppTheme.lime,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: spots.length <= 10,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: AppTheme.lime,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.lime.withOpacity(0.18),
                    AppTheme.lime.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    var path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
