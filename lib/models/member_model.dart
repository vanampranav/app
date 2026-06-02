import 'dart:convert';

/// User types for body composition calculation
enum UserType {
  standard,
  baby,
  toddler,
  child,
  teenager,
  athlete,
}

extension UserTypeExtension on UserType {
  String get displayName {
    switch (this) {
      case UserType.standard:
        return 'Standard';
      case UserType.baby:
        return 'Baby';
      case UserType.toddler:
        return 'Toddlers';
      case UserType.child:
        return 'Child';
      case UserType.teenager:
        return 'Teenager';
      case UserType.athlete:
        return 'Athlete';
    }
  }

  String get description {
    switch (this) {
      case UserType.baby:
        return 'Suitable for users under 3 years old. The measurement will automatically enter the baby holding mode, and others will assist in weighing.';
      case UserType.toddler:
        return 'Suitable for users aged 3-6 years old.';
      case UserType.child:
        return 'Suitable for users aged 6-12 years old.';
      case UserType.teenager:
        return 'Suitable for users aged 12-18 years old.';
      case UserType.athlete:
        return 'Suitable for professional athletes with high muscle mass.';
      default:
        return 'Standard measurement mode for adults.';
    }
  }

  /// Maps to FitDays SDK ICPeopleType
  String get sdkPeopleType {
    switch (this) {
      case UserType.athlete:
        return 'athlete';
      default:
        return 'normal';
    }
  }
}

/// Gender enum
enum Gender {
  male,
  female,
}

extension GenderExtension on Gender {
  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
    }
  }

  /// Maps to FitDays SDK ICSexType
  String get sdkSexType {
    switch (this) {
      case Gender.male:
        return 'male';
      case Gender.female:
        return 'female';
    }
  }
}

/// Member model for storing user data
class Member {
  final String id;
  final String nickname;
  final Gender gender;
  final DateTime birthdate;
  final int heightCm;
  final UserType userType;
  final String? avatarPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Member({
    required this.id,
    required this.nickname,
    required this.gender,
    required this.birthdate,
    required this.heightCm,
    this.userType = UserType.standard,
    this.avatarPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Calculate age from birthdate
  int get age {
    final now = DateTime.now();
    int age = now.year - birthdate.year;
    if (now.month < birthdate.month ||
        (now.month == birthdate.month && now.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  /// Create a copy with updated fields
  Member copyWith({
    String? id,
    String? nickname,
    Gender? gender,
    DateTime? birthdate,
    int? heightCm,
    UserType? userType,
    String? avatarPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Member(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      birthdate: birthdate ?? this.birthdate,
      heightCm: heightCm ?? this.heightCm,
      userType: userType ?? this.userType,
      avatarPath: avatarPath ?? this.avatarPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'gender': gender.index,
      'birthdate': birthdate.toIso8601String(),
      'heightCm': heightCm,
      'userType': userType.index,
      'avatarPath': avatarPath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      gender: Gender.values[json['gender'] as int],
      birthdate: DateTime.parse(json['birthdate'] as String),
      heightCm: json['heightCm'] as int,
      userType: UserType.values[json['userType'] as int? ?? 0],
      avatarPath: json['avatarPath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'Member(id: $id, nickname: $nickname, age: $age, height: $heightCm cm)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Member && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Body measurement data from scale
class BodyMeasurement {
  final String id;
  final String memberId;
  final DateTime timestamp;
  final double weightKg;
  final double? bmi;
  final double? bodyFatPercent;
  final double? muscleRatePercent;
  final double? leanBodyMassKg;
  final double? subcutaneousFatPercent;
  final double? visceralFat;
  final double? bodyWaterPercent;
  final double? skeletalMusclePercent;
  final double? muscleMassKg;
  final double? boneMassKg;
  final double? proteinPercent;
  final int? bmr;
  final int? bodyAge;
  final double? fatMassKg;
  final double? waterWeightKg;
  final double? proteinMassKg;
  final double? idealBodyWeightKg;

  BodyMeasurement({
    required this.id,
    required this.memberId,
    required this.timestamp,
    required this.weightKg,
    this.bmi,
    this.bodyFatPercent,
    this.muscleRatePercent,
    this.leanBodyMassKg,
    this.subcutaneousFatPercent,
    this.visceralFat,
    this.bodyWaterPercent,
    this.skeletalMusclePercent,
    this.muscleMassKg,
    this.boneMassKg,
    this.proteinPercent,
    this.bmr,
    this.bodyAge,
    this.fatMassKg,
    this.waterWeightKg,
    this.proteinMassKg,
    this.idealBodyWeightKg,
  });

  /// Check if measurement has body composition data
  bool get hasBodyComposition => bodyFatPercent != null && bodyFatPercent! > 0;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'timestamp': timestamp.toIso8601String(),
      'weightKg': weightKg,
      'bmi': bmi,
      'bodyFatPercent': bodyFatPercent,
      'muscleRatePercent': muscleRatePercent,
      'leanBodyMassKg': leanBodyMassKg,
      'subcutaneousFatPercent': subcutaneousFatPercent,
      'visceralFat': visceralFat,
      'bodyWaterPercent': bodyWaterPercent,
      'skeletalMusclePercent': skeletalMusclePercent,
      'muscleMassKg': muscleMassKg,
      'boneMassKg': boneMassKg,
      'proteinPercent': proteinPercent,
      'bmr': bmr,
      'bodyAge': bodyAge,
      'fatMassKg': fatMassKg,
      'waterWeightKg': waterWeightKg,
      'proteinMassKg': proteinMassKg,
      'idealBodyWeightKg': idealBodyWeightKg,
    };
  }

  /// Create from JSON
  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    return BodyMeasurement(
      id: json['id'] as String,
      memberId: json['memberId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      weightKg: (json['weightKg'] as num).toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
      muscleRatePercent: (json['muscleRatePercent'] as num?)?.toDouble(),
      leanBodyMassKg: (json['leanBodyMassKg'] as num?)?.toDouble(),
      subcutaneousFatPercent: (json['subcutaneousFatPercent'] as num?)?.toDouble(),
      visceralFat: (json['visceralFat'] as num?)?.toDouble(),
      bodyWaterPercent: (json['bodyWaterPercent'] as num?)?.toDouble(),
      skeletalMusclePercent: (json['skeletalMusclePercent'] as num?)?.toDouble(),
      muscleMassKg: (json['muscleMassKg'] as num?)?.toDouble(),
      boneMassKg: (json['boneMassKg'] as num?)?.toDouble(),
      proteinPercent: (json['proteinPercent'] as num?)?.toDouble(),
      bmr: (json['bmr'] as num?)?.toInt(),
      bodyAge: (json['bodyAge'] as num?)?.toInt(),
      fatMassKg: (json['fatMassKg'] as num?)?.toDouble(),
      waterWeightKg: (json['waterWeightKg'] as num?)?.toDouble(),
      proteinMassKg: (json['proteinMassKg'] as num?)?.toDouble(),
      idealBodyWeightKg: (json['idealBodyWeightKg'] as num?)?.toDouble(),
    );
  }

  /// Create from SDK weight data
  factory BodyMeasurement.fromWeightData(String memberId, Map<String, dynamic> data) {
    return BodyMeasurement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      memberId: memberId,
      timestamp: DateTime.now(),
      weightKg: (data['weight'] as num?)?.toDouble() ?? 0,
      bmi: (data['bmi'] as num?)?.toDouble(),
      bodyFatPercent: (data['bodyFat'] as num?)?.toDouble(),
      muscleRatePercent: (data['muscle'] as num?)?.toDouble(),
      bodyWaterPercent: (data['water'] as num?)?.toDouble(),
      boneMassKg: (data['boneMass'] as num?)?.toDouble(),
      proteinPercent: (data['protein'] as num?)?.toDouble(),
      bmr: (data['bmr'] as num?)?.toInt(),
      visceralFat: (data['visceralFat'] as num?)?.toDouble(),
      skeletalMusclePercent: (data['skeletalMuscle'] as num?)?.toDouble(),
      bodyAge: (data['physicalAge'] as num?)?.toInt(),
    );
  }
}
