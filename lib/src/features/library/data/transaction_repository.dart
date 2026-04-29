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
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookTransaction.fromMap(doc.data(), doc.id))
            .where((t) => !t.isDeletedByOwner) // Local filter for backward compatibility
            .toList());
  }

  Stream<List<BookTransaction>> watchOutgoingRequests(String userId) {
    return _firestore
        .collection('transactions')
        .where('borrowerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookTransaction.fromMap(doc.data(), doc.id))
            .where((t) => !t.isDeletedByBorrower) // Local filter for backward compatibility
            .toList());
  }

  Stream<BookTransaction?> watchActiveTransactionForBook(String userId, String bookId) {
    return _firestore
        .collection('transactions')
        .where('borrowerId', isEqualTo: userId)
        .where('bookId', isEqualTo: bookId)
        .snapshots()
        .map((snapshot) {
          final activeDocs = snapshot.docs
            .map((doc) => BookTransaction.fromMap(doc.data(), doc.id))
            .where((t) => !t.isDeletedByBorrower)
            .where((t) {
              return t.status != TransactionStatus.returned && t.status != TransactionStatus.canceled;
            });
          
          return activeDocs.isNotEmpty 
            ? activeDocs.first
            : null;
        });
  }

  Stream<BookTransaction?> watchAnyConfirmedTransactionForBook(String bookId) {
    return _firestore
        .collection('transactions')
        .where('bookId', isEqualTo: bookId)
        .snapshots()
        .map((snapshot) {
          final confirmedStatuses = [
            TransactionStatus.approved,
            TransactionStatus.pickedUp,
            TransactionStatus.overdue,
          ];
          
          final matches = snapshot.docs
              .map((doc) => BookTransaction.fromMap(doc.data(), doc.id))
              .where((t) => confirmedStatuses.contains(t.status));
              
          return matches.isNotEmpty ? matches.first : null;
        });
  }

  Future<void> requestBook({
    required String borrowerId,
    required String bookId,
    required String ownerId,
    required String communityId,
    required int durationWeeks,
  }) async {
    // Get user tier to check limits
    final userDoc = await _firestore.collection('users').doc(borrowerId).get();
    final isAdmin = userDoc.data()?['isAdmin'] ?? false;
    final isPro = userDoc.data()?['isPro'] ?? false;
    final maxBooks = isAdmin || isPro ? 10 : 5;

    final activeCount = await _firestore
        .collection('transactions')
        .where('borrowerId', isEqualTo: borrowerId)
        .where('status',
            whereIn: ['requested', 'approved', 'pickedUp', 'overdue'])
        .get()
        .then((snapshot) => snapshot.docs.length);
    
    if (activeCount >= maxBooks) {
      throw Exception('You have reached your limit of $maxBooks concurrent borrowed books. ${maxBooks == 5 ? "Upgrade to Pro for 10 books!" : ""}');
    }

    await _firestore.collection('transactions').add({
      'bookId': bookId,
      'borrowerId': borrowerId,
      'ownerId': ownerId,
      'communityId': communityId,
      'status': TransactionStatus.requested.name,
      'durationWeeks': durationWeeks,
      'requestedDate': FieldValue.serverTimestamp(),
      'isDeletedByOwner': false,
      'isDeletedByBorrower': false,
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

  Future<void> deleteTransaction(String transactionId, String userId) async {
    final docRef = _firestore.collection('transactions').doc(transactionId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final ownerId = data['ownerId'] as String;
    final borrowerId = data['borrowerId'] as String;

    bool isDeletedByOwner = data['isDeletedByOwner'] ?? false;
    bool isDeletedByBorrower = data['isDeletedByBorrower'] ?? false;

    if (userId == ownerId) isDeletedByOwner = true;
    if (userId == borrowerId) isDeletedByBorrower = true;

    // Soft delete for the party requesting it. Data remains in database forever.
    await docRef.update({
      'isDeletedByOwner': isDeletedByOwner,
      'isDeletedByBorrower': isDeletedByBorrower,
    });
  }

  Future<void> deleteMultipleTransactions(List<BookTransaction> transactions, String userId) async {
    final batch = _firestore.batch();
    for (var t in transactions) {
      final docRef = _firestore.collection('transactions').doc(t.id);
      
      bool isDeletedByOwner = t.isDeletedByOwner;
      bool isDeletedByBorrower = t.isDeletedByBorrower;

      if (userId == t.ownerId) isDeletedByOwner = true;
      if (userId == t.borrowerId) isDeletedByBorrower = true;

      // Update flags for soft deletion; never physically remove
      batch.update(docRef, {
        'isDeletedByOwner': isDeletedByOwner,
        'isDeletedByBorrower': isDeletedByBorrower,
      });
    }
    await batch.commit();
  }

  Future<void> cancelTransaction(String transactionId) async {
    await _firestore.collection('transactions').doc(transactionId).update({
      'status': TransactionStatus.canceled.name,
      'canceledDate': FieldValue.serverTimestamp(),
    });
  }

  Stream<BookTransaction?> watchTransaction(String transactionId) {
    return _firestore
        .collection('transactions')
        .doc(transactionId)
        .snapshots()
        .map((doc) => doc.exists ? BookTransaction.fromMap(doc.data()!, doc.id) : null);
  }
}

final transactionProvider = StreamProvider.family<BookTransaction?, String>((ref, transactionId) {
  return ref.watch(transactionRepositoryProvider).watchTransaction(transactionId);
});
