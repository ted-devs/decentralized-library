import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/book_transaction.dart';

final transactionRepositoryProvider = Provider((ref) => TransactionRepository(FirebaseFirestore.instance));

class TransactionRepository {
  final FirebaseFirestore _firestore;
  TransactionRepository(this._firestore);

  Stream<List<BookTransaction>> watchIncomingRequests(String userId) {
    return _firestore
        .collection('transactions')
        .where('ownerId', isEqualTo: userId)
        .where('status', isEqualTo: TransactionStatus.requested.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookTransaction.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<BookTransaction>> watchOutgoingRequests(String userId) {
    return _firestore
        .collection('transactions')
        .where('borrowerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookTransaction.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> requestBook({
    required String borrowerId,
    required String bookId,
    required String ownerId,
    required String communityId,
  }) async {
    // Check if the user has already borrowed too many books (limited to 3 for now)
    final activeCount = await _firestore
        .collection('transactions')
        .where('borrowerId', isEqualTo: borrowerId)
        .where('status', whereIn: ['approved', 'pickedUp'])
        .get()
        .then((snapshot) => snapshot.docs.length);
    
    if (activeCount >= 3) {
      throw Exception('You have reached the maximum of 3 concurrent borrowed books. Upgrade to Pro for more!');
    }

    await _firestore.collection('transactions').add({
      'bookId': bookId,
      'borrowerId': borrowerId,
      'ownerId': ownerId,
      'communityId': communityId,
      'status': TransactionStatus.requested.name,
      'durationWeeks': 4,
      'requestedDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveRequest(String transactionId, int durationWeeks) async {
    await _firestore.collection('transactions').doc(transactionId).update({
      'status': TransactionStatus.approved.name,
      'durationWeeks': durationWeeks,
      'approvedDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsPickedUp(String transactionId) async {
    await _firestore.collection('transactions').doc(transactionId).update({
      'status': TransactionStatus.pickedUp.name,
      'pickedUpDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsReturned(String transactionId) async {
    await _firestore.collection('transactions').doc(transactionId).update({
      'status': TransactionStatus.returned.name,
      'returnedDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelTransaction(String transactionId) async {
    await _firestore.collection('transactions').doc(transactionId).update({
      'status': TransactionStatus.canceled.name,
      'canceledDate': FieldValue.serverTimestamp(),
    });
  }
}
