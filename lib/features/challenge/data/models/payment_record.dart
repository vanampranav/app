import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_parsing.dart';

class PaymentRecord {
  final String id;
  final String userId;
  final String challengeId;
  final double amount;
  final String currency;
  final String method; // PaymentMethod
  final String status; // PaymentStatus
  final String? externalTransactionId;
  final String? proofImageUrl;
  final DateTime? paymentDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Admin fields
  final String? createdByAdminId;
  final String? lastUpdatedByAdminId;
  final String? adminNotes;

  PaymentRecord({
    required this.id,
    required this.userId,
    required this.challengeId,
    required this.amount,
    this.currency = 'USD',
    required this.method,
    required this.status,
    this.externalTransactionId,
    this.proofImageUrl,
    this.paymentDate,
    this.createdAt,
    this.updatedAt,
    this.createdByAdminId,
    this.lastUpdatedByAdminId,
    this.adminNotes,
  });

  PaymentRecord copyWith({
    String? id,
    String? userId,
    String? challengeId,
    double? amount,
    String? currency,
    String? method,
    String? status,
    String? externalTransactionId,
    String? proofImageUrl,
    DateTime? paymentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByAdminId,
    String? lastUpdatedByAdminId,
    String? adminNotes,
  }) {
    return PaymentRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      challengeId: challengeId ?? this.challengeId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      method: method ?? this.method,
      status: status ?? this.status,
      externalTransactionId: externalTransactionId ?? this.externalTransactionId,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      paymentDate: paymentDate ?? this.paymentDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      lastUpdatedByAdminId: lastUpdatedByAdminId ?? this.lastUpdatedByAdminId,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'challengeId': challengeId,
      'amount': amount,
      'currency': currency,
      'method': method,
      'status': status,
      'externalTransactionId': externalTransactionId,
      'proofImageUrl': proofImageUrl,
      'paymentDate': paymentDate != null ? Timestamp.fromDate(paymentDate!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdByAdminId': createdByAdminId,
      'lastUpdatedByAdminId': lastUpdatedByAdminId,
      'adminNotes': adminNotes,
    };
  }

  factory PaymentRecord.fromMap(Map<String, dynamic> map, String documentId) {
    return PaymentRecord(
      id: documentId,
      userId: map['userId'] ?? '',
      challengeId: map['challengeId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'USD',
      method: map['method'] ?? 'other',
      status: map['status'] ?? 'pending',
      externalTransactionId: map['externalTransactionId'],
      proofImageUrl: map['proofImageUrl'],
      paymentDate: parseFirestoreDate(map['paymentDate']),
      createdAt: parseFirestoreDate(map['createdAt']),
      updatedAt: parseFirestoreDate(map['updatedAt']),
      createdByAdminId: map['createdByAdminId'],
      lastUpdatedByAdminId: map['lastUpdatedByAdminId'],
      adminNotes: map['adminNotes'],
    );
  }

  factory PaymentRecord.fromFirestore(DocumentSnapshot doc) {
    return PaymentRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toFirestore() => toMap();
}
