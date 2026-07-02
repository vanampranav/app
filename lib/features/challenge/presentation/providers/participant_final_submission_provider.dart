import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_submission.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/submission_review_service.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class ParticipantFinalSubmissionProvider with ChangeNotifier {
  final String challengeId;
  final String userId;
  final ChallengeRepository _challengeRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeSubmissionRepository _submissionRepository;
  final SubmissionReviewService _submissionService;

  Challenge? _challenge;
  ChallengeParticipant? _participant;
  ChallengeSubmission? _baseline;
  ChallengeSubmission? _existingFinalSubmission;

  bool _isLoading = true;
  bool _isUploading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<File> _newPhotos = [];
  List<String> _existingPhotoUrls = [];

  Challenge? get challenge => _challenge;
  ChallengeParticipant? get participant => _participant;
  ChallengeSubmission? get baseline => _baseline;
  ChallengeSubmission? get existingFinalSubmission => _existingFinalSubmission;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<File> get newPhotos => _newPhotos;
  List<String> get existingPhotoUrls => _existingPhotoUrls;

  bool get isWindowOpen {
    if (_challenge == null) return false;
    final now = DateTime.now();
    return now.isAfter(_challenge!.endDate.subtract(const Duration(days: 3)));
  }

  ParticipantFinalSubmissionProvider({
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
      final challengeSubmissions = submissions.where((s) => s.challengeId == challengeId).toList();
      
      try {
        _baseline = challengeSubmissions.firstWhere(
          (s) => s.type == SubmissionType.baseline && s.reviewStatus == ReviewStatus.approved,
        );
      } catch (_) {
        _baseline = null;
      }

      try {
        _existingFinalSubmission = challengeSubmissions.firstWhere(
          (s) => s.type == SubmissionType.finalSubmission,
        );
        _existingPhotoUrls = List<String>.from(_existingFinalSubmission?.data['photos'] ?? []);
      } catch (_) {
        _existingFinalSubmission = null;
        _existingPhotoUrls = [];
      }
    } catch (e) {
      _errorMessage = 'Error loading final data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
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

  Future<void> submitFinalSubmission({
    required double weight,
    required String unit,
    double? bodyFat,
    required String source,
    String? notes,
  }) async {
    if (_challenge == null) return;

    if (_challenge!.finalPhotoRequired && _newPhotos.isEmpty && _existingPhotoUrls.isEmpty) {
      _errorMessage = 'At least one final photo is required for prize eligibility.';
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
              .child('final')
              .child('$timestamp.jpg');

          final uploadTask = await storageRef.putFile(file);
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

      await _submissionService.submitFinalSubmission(userId, challengeId, submissionData);
      
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
