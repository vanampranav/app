import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member_model.dart';

/// Service for managing members and measurements
class MemberService {
  static const String _membersKey = 'members_list';
  static const String _activeMemberKey = 'active_member_id';
  static const String _measurementsKeyPrefix = 'measurements_';

  SharedPreferences? _prefs;

  /// Initialize shared preferences
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get all members
  Future<List<Member>> getMembers() async {
    await _ensureInitialized();
    final json = _prefs!.getString(_membersKey);
    if (json == null) return [];
    
    try {
      final List<dynamic> list = jsonDecode(json);
      return list.map((e) => Member.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading members: $e');
      return [];
    }
  }

  /// Get member by ID
  Future<Member?> getMember(String id) async {
    final members = await getMembers();
    try {
      return members.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get active member
  Future<Member?> getActiveMember() async {
    await _ensureInitialized();
    final activeId = _prefs!.getString(_activeMemberKey);
    if (activeId == null) {
      // Return first member if no active member set
      final members = await getMembers();
      return members.isNotEmpty ? members.first : null;
    }
    return getMember(activeId);
  }

  /// Set active member
  Future<void> setActiveMember(String memberId) async {
    await _ensureInitialized();
    await _prefs!.setString(_activeMemberKey, memberId);
  }

  /// Add a new member
  Future<Member> addMember(Member member) async {
    await _ensureInitialized();
    final members = await getMembers();
    members.add(member);
    await _saveMembers(members);
    
    // Set as active if it's the first member
    if (members.length == 1) {
      await setActiveMember(member.id);
    }
    
    return member;
  }

  /// Update a member
  Future<Member> updateMember(Member member) async {
    await _ensureInitialized();
    final members = await getMembers();
    final index = members.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      members[index] = member.copyWith(updatedAt: DateTime.now());
      await _saveMembers(members);
    }
    return member;
  }

  /// Delete a member
  Future<void> deleteMember(String memberId) async {
    await _ensureInitialized();
    final members = await getMembers();
    members.removeWhere((m) => m.id == memberId);
    await _saveMembers(members);
    
    // Clear measurements for this member
    await _prefs!.remove('$_measurementsKeyPrefix$memberId');
    
    // Update active member if deleted
    final activeId = _prefs!.getString(_activeMemberKey);
    if (activeId == memberId && members.isNotEmpty) {
      await setActiveMember(members.first.id);
    }
  }

  /// Save members list
  Future<void> _saveMembers(List<Member> members) async {
    final json = jsonEncode(members.map((m) => m.toJson()).toList());
    await _prefs!.setString(_membersKey, json);
  }

  /// Get measurements for a member
  Future<List<BodyMeasurement>> getMeasurements(String memberId, {int? limit}) async {
    await _ensureInitialized();
    final key = '$_measurementsKeyPrefix$memberId';
    final json = _prefs!.getString(key);
    if (json == null) return [];
    
    try {
      final List<dynamic> list = jsonDecode(json);
      var measurements = list.map((e) => BodyMeasurement.fromJson(e)).toList();
      // Sort by timestamp descending (newest first)
      measurements.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (limit != null && measurements.length > limit) {
        measurements = measurements.sublist(0, limit);
      }
      return measurements;
    } catch (e) {
      debugPrint('Error loading measurements: $e');
      return [];
    }
  }

  /// Get latest measurement for a member
  Future<BodyMeasurement?> getLatestMeasurement(String memberId) async {
    final measurements = await getMeasurements(memberId, limit: 1);
    return measurements.isNotEmpty ? measurements.first : null;
  }

  /// Add a measurement
  Future<BodyMeasurement> addMeasurement(BodyMeasurement measurement) async {
    await _ensureInitialized();
    final key = '$_measurementsKeyPrefix${measurement.memberId}';
    final measurements = await getMeasurements(measurement.memberId);
    
    // Check for duplicates (within 1 minute threshold)
    final existingIndex = measurements.indexWhere((m) => 
      m.timestamp.difference(measurement.timestamp).inMinutes.abs() < 1 &&
      m.weightKg == measurement.weightKg &&
      m.bodyFatPercent == measurement.bodyFatPercent
    );

    if (existingIndex != -1) {
       // Update existing if needed, or just return it
       // For now, let's just return the existing one to avoid duplication
       return measurements[existingIndex];
    }

    measurements.add(measurement);
    
    final json = jsonEncode(measurements.map((m) => m.toJson()).toList());
    await _prefs!.setString(key, json);
    
    return measurement;
  }

  /// Remove duplicate measurements
  Future<void> removeDuplicates(String memberId) async {
    await _ensureInitialized();
    final key = '$_measurementsKeyPrefix$memberId';
    final measurements = await getMeasurements(memberId);
    
    final uniqueMeasurements = <BodyMeasurement>[];
    final seen = <String>{};
    
    for (var m in measurements) {
      // Create a unique key based on time (to minute) and weight
      // timestamp is DateTime, let's round to minute
      final timeKey = '${m.timestamp.year}-${m.timestamp.month}-${m.timestamp.day} ${m.timestamp.hour}:${m.timestamp.minute}';
      final uniqueKey = '$timeKey-${m.weightKg}-${m.bodyFatPercent}';
      
      if (!seen.contains(uniqueKey)) {
        seen.add(uniqueKey);
        uniqueMeasurements.add(m);
      }
    }
    
    if (uniqueMeasurements.length != measurements.length) {
       final json = jsonEncode(uniqueMeasurements.map((m) => m.toJson()).toList());
       await _prefs!.setString(key, json);
    }
  }

  /// Delete a measurement
  Future<void> deleteMeasurement(String memberId, String measurementId) async {
    await _ensureInitialized();
    final key = '$_measurementsKeyPrefix$memberId';
    final measurements = await getMeasurements(memberId);
    measurements.removeWhere((m) => m.id == measurementId);
    
    final json = jsonEncode(measurements.map((m) => m.toJson()).toList());
    await _prefs!.setString(key, json);
  }

  /// Get measurements for a date range
  Future<List<BodyMeasurement>> getMeasurementsInRange(
    String memberId, 
    DateTime start, 
    DateTime end,
  ) async {
    final measurements = await getMeasurements(memberId);
    return measurements.where((m) => 
      m.timestamp.isAfter(start) && m.timestamp.isBefore(end)
    ).toList();
  }

  /// Generate a unique ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           '_${DateTime.now().microsecond}';
  }

  /// Create a member using onboarding profile data from SharedPreferences.
  /// Falls back to a generic default if no onboarding data is present.
  Future<Member> createDefaultMember() async {
    await _ensureInitialized();
    final name      = _prefs!.getString('user_name')       ?? '';
    final genderStr = _prefs!.getString('user_gender')     ?? 'male';
    final birthYear = _prefs!.getInt('user_birth_year')    ?? 1990;
    final birthMonth= _prefs!.getInt('user_birth_month')   ?? 1;
    final birthDay  = _prefs!.getInt('user_birth_day')     ?? 1;
    final heightRaw = _prefs!.getDouble('user_height_cm')  ?? 170.0;

    final nickname  = name.trim().split(' ').firstWhere((s) => s.isNotEmpty,
        orElse: () => 'User');
    final gender    = genderStr == 'female' ? Gender.female : Gender.male;
    final birthdate = DateTime(birthYear, birthMonth, birthDay);
    final heightCm  = heightRaw.round().clamp(50, 300);

    final member = Member(
      id: generateId(),
      nickname: nickname,
      gender: gender,
      birthdate: birthdate,
      heightCm: heightCm,
      userType: UserType.standard,
    );
    return addMember(member);
  }

  /// Ensure at least one member exists.
  /// On first launch after onboarding, creates the member from the onboarding
  /// profile so the FitDays SDK is immediately calibrated correctly.
  Future<Member> ensureMemberExists() async {
    final members = await getMembers();
    if (members.isEmpty) {
      return createDefaultMember();
    }
    return (await getActiveMember()) ?? members.first;
  }
}
