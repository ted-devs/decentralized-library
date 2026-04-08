import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/book_transaction.dart';
import 'package:decentralized_library/src/features/notifications/domain/app_notification.dart';

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

  Stream<BookTransaction?> watchActiveTransactionForBook(String userId, String bookId) {
    return _firestore
        .collection('transactions')
        .where('borrowerId', isEqualTo: userId)
        .where('bookId', isEqualTo: bookId)
        .snapshots()
        .map((snapshot) {
          final activeDocs = snapshot.docs.where((doc) {
            final data = doc.data();
            final statusStr = data['status'] as String?;
            if (statusStr == null) return false;
            
            // Safe parsing to check if it's active (not returned or canceled)
            final normalized = statusStr.toLowerCase().replaceAll('_', '');
            return normalized != 'returned' && normalized != 'canceled';
          });
          
          return activeDocs.isNotEmpty 
            ? BookTransaction.fromMap(activeDocs.first.data(), activeDocs.first.id) 
            : null;
        });
  }

  Stream<BookTransaction?> watchAnyConfirmedTransactionForBook(String bookId) {
    return _firestore
        .collection('transactions')
        .where('bookId', isEqualTo: bookId)
        .where('status', whereIn: [
          TransactionStatus.approved.name,
          TransactionStatus.pickedUp.name,
          TransactionStatus.overdue.name,
        ])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.isNotEmpty
              ? BookTransaction.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id)
              : null;
        });
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

    // Send notification to book owner
    final borrowerDoc = await _firestore.collection('users').doc(borrowerId).get();
    final borrowerName = borrowerDoc.data()?['displayName'] ?? 'A user';

    await _firestore.collection('notifications').add({
      'recipientId': ownerId,
      'senderId': borrowerId,
      'type': NotificationType.borrowRequest.name,
      'title': 'New Book Request!',
      'body': '$borrowerName wants to borrow a book from you.',
      'relatedId': bookId,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> approveRequest(String transactionId, int durationWeeks) async {
    await _firestore.collection('transactions').doc(transactionId).update({
      'status': TransactionStatus.approved.name,
      'durationWeeks': durationWeeks,
      'approvedDate': FieldValue.serverTimestamp(),
    });

    // Notify borrower
    final transactionDoc = await _firestore.collection('transactions').doc(transactionId).get();
    final borrowerId = transactionDoc.data()?['borrowerId'];

    if (borrowerId != null) {
      await _firestore.collection('notifications').add({
        'recipientId': borrowerId,
        'type': NotificationType.borrowApproved.name,
        'title': 'Request Approved!',
        'body': 'Your book borrowing request has been approved.',
        'relatedId': transactionId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }
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

  Future<void> deleteTransaction(String transactionId) async {
    await _firestore.collection('transactions').doc(transactionId).delete();
  }

  Future<void> cancelTransaction(String transactionId) async {
    await _firestore.collection('transactions').doc(transactionId).update({
      'status': TransactionStatus.canceled.name,
      'canceledDate': FieldValue.serverTimestamp(),
    });
  }
}
