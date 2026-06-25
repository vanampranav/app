import 'package:elefit_app/features/challenge/data/models/admin_audit_log.dart';
import 'package:elefit_app/features/challenge/data/repositories/admin_audit_log_repository.dart';

class AdminAuditService {
  final AdminAuditLogRepository _auditLogRepository;

  AdminAuditService({required AdminAuditLogRepository auditLogRepository})
      : _auditLogRepository = auditLogRepository;

  Future<void> logAction({
    required String adminId,
    String? challengeId,
    required String action,
    required String targetCollection,
    required String targetId,
    Map<String, dynamic>? previousData,
    Map<String, dynamic>? newData,
    String? reason,
  }) async {
    final log = AdminAuditLog(
      id: '', // Firestore will generate
      adminId: adminId,
      challengeId: challengeId,
      action: action,
      targetCollection: targetCollection,
      targetId: targetId,
      previousData: previousData,
      newData: newData,
      reason: reason,
      createdAt: DateTime.now(),
    );

    await _auditLogRepository.createAuditLog(log);
  }

  Stream<List<AdminAuditLog>> streamChallengeAuditLogs(String challengeId) {
    return _auditLogRepository.streamAuditLogsByChallenge(challengeId);
  }
}
