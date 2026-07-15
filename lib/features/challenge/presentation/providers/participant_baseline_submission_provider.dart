import 'dart:async';
import 'package:elefit_app/features/challenge/presentation/providers/challenge_error_text.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/submission_review_service.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/services/member_service.dart';
import 'package:elefit_app/services/analytics_service.dart';

class ParticipantBaselineSubmissionProvider with ChangeNotifier {
  final String challengeId;
  final String userId;
  final ChallengeRepository _challengeRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeSubmissionRepository _submissionRepository;
  final SubmissionReviewService _submissionService;
  final MemberService _memberService = MemberService();

  Challenge? _challenge;
  ChallengeParticipant? _participant;
  ChallengeSubmission? _existingSubmission;

  bool _isLoading = true;
  bool _isUploading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<File> _newPhotos = [];
  List<String> _existingPhotoUrls = [];

  // Prefill Data
  double? _prefilledWeight;
  double? _prefilledBodyFat;
  String? _prefilledUnit;
  bool _hasProfilePrefill = false;

  Challenge? get challenge => _challenge;
  ChallengeParticipant? get participant => _participant;
  ChallengeSubmission? get existingSubmission => _existingSubmission;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<File> get newPhotos => _newPhotos;
  List<String> get existingPhotoUrls => _existingPhotoUrls;

  double? get prefilledWeight => _prefilledWeight;
  double? get prefilledBodyFat => _prefilledBodyFat;
  String? get prefilledUnit => _prefilledUnit;
  bool get hasProfilePrefill => _hasProfilePrefill;

  ParticipantBaselineSubmissionProvider({
    required this.challengeId,
    required this.userId,
    required ChallengeRepository challengeRepository,
    required ChallengeParticipantRepository participantRepository,
    required ChallengeSubmissionRepository submissionRepository,
    required SubmissionReviewService submissionService,
  })  : _challengeRepository = challengeRepository,
        _participantRepository = participantRepository,
        _submissionRepository = submissionRepository,
        _submissionService = submissionService {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _challenge = await _challengeRepository.getChallengeById(challengeId);
      _participant = await _participantRepository.getParticipantByUserAndChallenge(userId, challengeId);
      
      final submissions = await _submissionRepository.streamSubmissionsByParticipant(userId).first;
      try {
        _existingSubmission = submissions.firstWhere(
          (s) => s.challengeId == challengeId && s.type == SubmissionType.baseline,
        );
        _existingPhotoUrls = List<String>.from(_existingSubmission?.data['photos'] ?? []);
      } catch (_) {
        _existingSubmission = null;
      }

      if (_existingSubmission == null) {
        await _loadPrefillData();
      }
    } catch (e) {
      _errorMessage = 'Error loading baseline data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPrefillData() async {
    try {
      final member = await _memberService.getActiveMember();
      if (member != null) {
        final latest = await _memberService.getLatestMeasurement(member.id);
        if (latest != null) {
          _prefilledWeight = latest.weightKg;
          _prefilledBodyFat = latest.bodyFatPercent;
          _prefilledUnit = 'kg'; // Default in member service seems to be kg
          _hasProfilePrefill = true;
        }
      }

      // Fallback to SharedPreferences (Onboarding data)
      if (!_hasProfilePrefill) {
        final prefs = await SharedPreferences.getInstance();
        final weight = prefs.getDouble('user_weight_kg');
        if (weight != null) {
          _prefilledWeight = weight;
          _prefilledUnit = 'kg';
          _hasProfilePrefill = true;
        }
      }
    } catch (e) {
      debugPrint('Error loading prefill data: $e');
    }
  }

  void addPhoto(File file) {
    _newPhotos.add(file);
    notifyListeners();
  }

  void removeNewPhoto(int index) {
    _newPhotos.removeAt(index);
    notifyListeners();
  }

  void removeExistingPhoto(int index) {
    _existingPhotoUrls.removeAt(index);
    notifyListeners();
  }

  Future<void> submitBaseline({
    required double weight,
    required String unit,
    double? bodyFat,
    required String source,
    String? notes,
  }) async {
    if (_challenge == null) return;

    if (_challenge!.baselineRequired && _newPhotos.isEmpty && _existingPhotoUrls.isEmpty) {
      _errorMessage = 'At least one photo is required for this challenge.';
      notifyListeners();
      return;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      List<String> finalPhotoUrls = List.from(_existingPhotoUrls);

      if (_newPhotos.isNotEmpty) {
        _isUploading = true;
        notifyListeners();

        for (var file in _newPhotos) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('challenge_submissions')
              .child(challengeId)
              .child(userId)
              .child('baseline')
              .child('$timestamp.jpg');

          final uploadTask = await storageRef.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
          final url = await uploadTask.ref.getDownloadURL();
          finalPhotoUrls.add(url);
        }
        _isUploading = false;
        notifyListeners();
      }

      final submissionData = {
        'weight': weight,
        'unit': unit,
        'bodyFat': bodyFat,
        'source': source,
        'notes': notes,
        'photos': finalPhotoUrls,
      };

      await _submissionService.submitBaseline(userId, challengeId, submissionData);
      await AnalyticsService.logBaselineSubmitted(challengeId, source);
      
    } catch (e) {
      _errorMessage = friendlyChallengeError(e);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
