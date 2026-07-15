import 'dart:async';
import 'package:elefit_app/features/challenge/presentation/providers/challenge_error_text.dart';
import 'package:elefit_app/features/challenge/challenge_auth_guard.dart';
import 'dart:io';
import 'dart:typed_data';
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
import 'package:elefit_app/services/analytics_service.dart';

class ParticipantWeeklyCheckinProvider with ChangeNotifier {
  final String challengeId;
  final String userId;
  final ChallengeRepository _challengeRepository;
  final ChallengeParticipantRepository _participantRepository;
  final ChallengeSubmissionRepository _submissionRepository;
  final SubmissionReviewService _submissionService;

  Challenge? _challenge;
  ChallengeParticipant? _participant;
  ChallengeSubmission? _baseline;
  ChallengeSubmission? _existingWeeklyForCurrentWeek;
  
  List<ChallengeSubmission> _allWeeklySubmissions = [];

  bool _isLoading = true;
  bool _isUploading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<File> _newPhotos = [];
  List<String> _existingPhotoUrls = [];
  int _currentWeekNumber = 1;

  Challenge? get challenge => _challenge;
  ChallengeParticipant? get participant => _participant;
  ChallengeSubmission? get baseline => _baseline;
  ChallengeSubmission? get currentWeekSubmission => _existingWeeklyForCurrentWeek;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<File> get newPhotos => _newPhotos;
  List<String> get existingPhotoUrls => _existingPhotoUrls;
  int get currentWeekNumber => _currentWeekNumber;

  ParticipantWeeklyCheckinProvider({
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
      
      if (_challenge != null) {
        final now = DateTime.now();
        final diff = now.difference(_challenge!.startDate).inDays;
        _currentWeekNumber = (diff / 7).floor() + 1;
        if (_currentWeekNumber < 1) _currentWeekNumber = 1;
      }

      final submissions = await _submissionRepository.streamSubmissionsByParticipant(userId).first;
      final challengeSubmissions = submissions.where((s) => s.challengeId == challengeId).toList();
      
      try {
        _baseline = challengeSubmissions.firstWhere(
          (s) => s.type == SubmissionType.baseline && s.reviewStatus == ReviewStatus.approved,
        );
      } catch (_) {
        _baseline = null;
      }

      _allWeeklySubmissions = challengeSubmissions.where((s) => s.type == SubmissionType.weeklyCheckIn).toList();
      
      try {
        _existingWeeklyForCurrentWeek = _allWeeklySubmissions.firstWhere(
          (s) => s.data['weekNumber'] == _currentWeekNumber,
        );
        _existingPhotoUrls = List<String>.from(_existingWeeklyForCurrentWeek?.data['photos'] ?? []);
      } catch (_) {
        _existingWeeklyForCurrentWeek = null;
        _existingPhotoUrls = [];
      }
    } catch (e) {
      _errorMessage = 'Error loading weekly data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Bytes captured at pick time, kept in lock-step with _newPhotos, so uploads
  // never depend on image_picker's temp file still existing at submit time.
  final List<Uint8List> _newPhotoBytes = [];

  void addPhoto(File file, Uint8List bytes) {
    _newPhotos.add(file);
    _newPhotoBytes.add(bytes);
    notifyListeners();
  }

  void removeNewPhoto(int index) {
    _newPhotos.removeAt(index);
    _newPhotoBytes.removeAt(index);
    notifyListeners();
  }

  void removeExistingPhoto(int index) {
    _existingPhotoUrls.removeAt(index);
    notifyListeners();
  }

  Future<void> submitWeeklyCheckIn({
    required double weight,
    required String unit,
    double? bodyFat,
    required String source,
    String? notes,
  }) async {
    if (_challenge == null) return;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ensureFirebaseSdkSignedIn();
      List<String> finalPhotoUrls = List.from(_existingPhotoUrls);

      if (_newPhotos.isNotEmpty) {
        _isUploading = true;
        notifyListeners();

        for (var bytes in _newPhotoBytes) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('challenge_submissions')
              .child(challengeId)
              .child(userId)
              .child('weekly')
              .child(_currentWeekNumber.toString())
              .child('$timestamp.jpg');

          final uploadTask = await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
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
        'weekNumber': _currentWeekNumber,
      };

      await _submissionService.submitWeeklyCheckIn(userId, challengeId, submissionData);
      await AnalyticsService.logWeeklyCheckinSubmitted(challengeId, _currentWeekNumber);
      
    } catch (e) {
      _errorMessage = friendlyChallengeError(e);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
