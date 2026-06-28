import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/models/payment_record.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/payment_record_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/payment_approval_service.dart';

class ParticipantPaymentSubmissionProvider with ChangeNotifier {
  final String challengeId;
  final String userId;
  final ChallengeRepository _challengeRepository;
  final ChallengeParticipantRepository _participantRepository;
  final PaymentRecordRepository _paymentRepository;
  final PaymentApprovalService _paymentService;

  Challenge? _challenge;
  ChallengeParticipant? _participant;
  PaymentRecord? _existingPayment;
  
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  
  File? _proofImage;
  String? _proofImageUrl;

  Challenge? get challenge => _challenge;
  ChallengeParticipant? get participant => _participant;
  PaymentRecord? get existingPayment => _existingPayment;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  File? get proofImage => _proofImage;
  String? get proofImageUrl => _proofImageUrl;

  ParticipantPaymentSubmissionProvider({
    required this.challengeId,
    required this.userId,
    required ChallengeRepository challengeRepository,
    required ChallengeParticipantRepository participantRepository,
    required PaymentRecordRepository paymentRepository,
    required PaymentApprovalService paymentService,
  })  : _challengeRepository = challengeRepository,
        _participantRepository = participantRepository,
        _paymentRepository = paymentRepository,
        _paymentService = paymentService {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _challenge = await _challengeRepository.getChallengeById(challengeId);
      _participant = await _participantRepository.getParticipantByUserAndChallenge(userId, challengeId);
      
      if (kDebugMode) {
        debugPrint('PaymentSubmission: Loaded participant. paymentStatus: ${_participant?.paymentStatus}');
      }

      final payments = await _paymentRepository.streamPaymentsByUser(userId).first;
      try {
        _existingPayment = payments.firstWhere((p) => p.challengeId == challengeId);
        _proofImageUrl = _existingPayment?.proofImageUrl;
      } catch (_) {
        _existingPayment = null;
      }
    } catch (e) {
      _errorMessage = 'Error loading data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setProofImage(File file) {
    _proofImage = file;
    notifyListeners();
  }

  Future<void> submitPayment({
    required String method,
    required String amount,
    required String? referenceId,
  }) async {
    if (_proofImage == null && _proofImageUrl == null) {
      _errorMessage = 'Payment proof image is required.';
      notifyListeners();
      return;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? finalUrl = _proofImageUrl;

      if (_proofImage != null) {
        _isUploading = true;
        notifyListeners();
        
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('payment_proofs')
            .child(challengeId)
            .child('$userId-${DateTime.now().millisecondsSinceEpoch}.jpg');
            
        final uploadTask = await storageRef.putFile(_proofImage!);
        finalUrl = await uploadTask.ref.getDownloadURL();
        
        _isUploading = false;
        notifyListeners();
      }

      await _paymentService.submitManualPayment(
        userId: userId,
        challengeId: challengeId,
        amount: double.parse(amount),
        method: method,
        externalTransactionId: referenceId,
        proofImageUrl: finalUrl,
      );

    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
