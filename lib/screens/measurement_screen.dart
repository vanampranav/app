import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/device_model.dart';
import '../models/member_model.dart';
import '../services/fitdays_service.dart';
import '../services/member_service.dart';
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
  Member? _activeMember;
  List<Member> _members = [];
  bool _isConnected = true;
  bool _isLoading = true;
  
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
        getValue: () => null, // Not available from SDK
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
    _loadData();
    _setupListeners();
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
        await widget.fitDaysService.initializeSDK(
          age: _activeMember!.age,
          height: _activeMember!.heightCm,
          sex: _activeMember!.gender.sdkSexType,
        );
      }
    } catch (e) {
      print('Error loading data: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _setupListeners() {
    widget.fitDaysService.weightDataStream.listen((measurement) {
      if (mounted) {
        setState(() {
          _latestMeasurement = measurement;
          _isConnected = true;
        });
        
        // Save measurement if we have body composition data
        if (measurement.hasBodyComposition && _activeMember != null) {
          _saveMeasurement(measurement);
        }
      }
    });

    widget.fitDaysService.connectionStateStream.listen((state) {
      final deviceMac = state['macAddress'] ?? state['deviceId'];
      if (mounted && deviceMac == widget.connectedDevice.macAddress) {
        setState(() {
          _isConnected = state['state'] == 'connected';
        });
      }
    });
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
  }

  void _showMemberSelector() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._members.map((member) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[300],
                child: Text(
                  member.nickname.isNotEmpty ? member.nickname[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(member.nickname),
              trailing: _activeMember?.id == member.id
                  ? Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 16),
                    )
                  : Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
              onTap: () async {
                await _memberService.setActiveMember(member.id);
                setState(() => _activeMember = member);
                
                // Update SDK with new user info
                await widget.fitDaysService.initializeSDK(
                  age: member.age,
                  height: member.heightCm,
                  sex: member.gender.sdkSexType,
                );
                
                Navigator.pop(context);
              },
            )),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.people_outline, color: Colors.grey[600]),
              title: Text('Management', style: TextStyle(color: Colors.grey[600])),
              onTap: () {
                Navigator.pop(context);
                _showMemberManagement();
              },
            ),
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
    if (result != null) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                    _buildBabyPetModeCard(),
                    _buildTargetCard(),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showMemberSelector,
            child: Row(
              children: [
                Text(
                  _activeMember?.nickname ?? 'User',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.person, color: Colors.grey[600], size: 20),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildWeightCard() {
    final weight = _latestMeasurement?.weight ?? 0.0;
    final timestamp = DateTime.now();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                weight.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w300,
                  color: Colors.black87,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    const Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM d, yyyy HH:mm').format(timestamp),
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildComparedSection() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Compared',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Text(
                    DateFormat('MMM d, yyyy HH:mm').format(DateTime.now()),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildCompareItem('Weight', '${_latestMeasurement?.weight.toStringAsFixed(1) ?? '0.0'} kg'),
              _buildCompareItem('BMI', _latestMeasurement?.bmi?.toStringAsFixed(1) ?? '0.0'),
              _buildCompareItem('Body Fat', '${_latestMeasurement?.bodyFat?.toStringAsFixed(1) ?? '0.0'} %'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompareItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '- $label',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyIndexSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Body Index',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ..._bodyIndexMetrics.map((metric) => _buildBodyIndexRow(metric)),
        ],
      ),
    );
  }

  Widget _buildBodyIndexRow(BodyIndexMetric metric) {
    final value = metric.getValue();
    final statusColor = metric.getStatusColor(value);
    
    return InkWell(
      onTap: () => _showMetricDetailSheet(metric),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: metric.iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(metric.icon, color: metric.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(metric.name, style: const TextStyle(fontSize: 14)),
            ),
            Text(
              value != null 
                  ? '${value.toStringAsFixed(metric.unit == 'kcal' || metric.id == 'bodyAge' ? 0 : 1)} ${metric.unit}'
                  : '-- ${metric.unit}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMetricDetailSheet(BodyIndexMetric metric) {
    final metrics = _bodyIndexMetrics;
    final initialIndex = metrics.indexWhere((m) => m.id == metric.id);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MetricDetailSheet(
        metrics: metrics,
        initialIndex: initialIndex,
      ),
    );
  }

  Widget _buildDisclaimerSection() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Disclaimer: This product is not a medical device, and the measurement results cannot be used as medical diagnosis results.',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildTrendSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Icon(Icons.expand_less, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Center(
              child: Text(
                'Weight trend chart',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBabyPetModeCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.child_care, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 12),
          const Text('Baby / Pet Mode', style: TextStyle(fontSize: 16)),
          const Spacer(),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildTargetCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Target', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "You haven't set a goal yet. Click Set Up.",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
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
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            tabs: widget.metrics.map((m) => Tab(text: m.name)).toList(),
          ),
          // Page content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.metrics.length,
              onPageChanged: (index) {
                _tabController.animateTo(index);
              },
              itemBuilder: (context, index) {
                return _buildMetricContent(widget.metrics[index]);
              },
            ),
          ),
          // Close button
          SafeArea(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricContent(BodyIndexMetric metric) {
    final value = metric.getValue();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Large value display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value != null 
                    ? value.toStringAsFixed(metric.unit == 'kcal' || metric.id == 'bodyAge' ? 0 : 1)
                    : '--',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w300,
                  color: Colors.black87,
                ),
              ),
              if (metric.unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    metric.unit,
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Scale bar
          _buildScaleBar(metric, value),
          const SizedBox(height: 24),
          // Divider
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 16),
          // Description
          Text(
            metric.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                Positioned(
                  left: 0,
                  right: 0,
                  top: -4,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final markerX = userPosition! * constraints.maxWidth;
                      return Stack(
                        children: [
                          Positioned(
                            left: markerX - 8,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primaryColor, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
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
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
