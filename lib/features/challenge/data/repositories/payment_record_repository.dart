import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/payment_record.dart';

class PaymentRecordRepository {
  final FirebaseFirestore _firestore;

  PaymentRecordRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection =>
      _firestore.collection(FirestoreCollections.paymentRecords);

  Future<String> createPaymentRecord(PaymentRecord payment) async {
    try {
      final docRef = _collection.doc(payment.id.isEmpty ? null : payment.id);
      await docRef.set(
        payment.toFirestore(),
        SetOptions(merge: true),
      );
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create payment record: $e');
    }
  }

  Future<void> updatePaymentRecord(PaymentRecord payment) async {
    try {
      await _collection.doc(payment.id).update(payment.toFirestore());
    } catch (e) {
      throw Exception('Failed to update payment record: $e');
    }
  }

  Future<PaymentRecord?> getPaymentRecord(String paymentId) async {
    try {
      final doc = await _collection.doc(paymentId).get();
      if (!doc.exists) return null;
      return PaymentRecord.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get payment record: $e');
    }
  }

  Stream<List<PaymentRecord>> streamPaymentsByChallenge(String challengeId) {
    return _collection
        .where('challengeId', isEqualTo: challengeId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentRecord.fromFirestore(doc))
            .toList());
  }

  Stream<List<PaymentRecord>> streamPaymentsByUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentRecord.fromFirestore(doc))
            .toList());
  }

  Stream<List<PaymentRecord>> streamPendingPayments(String challengeId) {
    return _collection
        .where('challengeId', isEqualTo: challengeId)
        .where('status', isEqualTo: PaymentStatus.pending)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentRecord.fromFirestore(doc))
            .toList());
  }
}
