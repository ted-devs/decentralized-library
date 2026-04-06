import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';
import 'package:decentralized_library/src/features/library/domain/book_transaction.dart';

final bookshelfRepositoryProvider = Provider((ref) => BookshelfRepository(FirebaseFirestore.instance));

class BookshelfRepository {
  final FirebaseFirestore _firestore;
  BookshelfRepository(this._firestore);

  Stream<List<Book>> watchOwnedBooks(String userId) {
    return _firestore
        .collection('books')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Book.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Book>> watchCommunityLibrary(List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);
    
    // Firestore whereIn has a limit of 30
    final limitedIds = userIds.take(30).toList();
    
    return _firestore
        .collection('books')
        .where('ownerId', whereIn: limitedIds)
        .where('isShareable', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Book.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<BookTransaction>> watchLentTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('ownerId', isEqualTo: userId)
        .where('status', whereIn: ['approved', 'picked_up', 'overdue'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookTransaction.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Book>> watchBorrowedBooks(String userId) {
    return _firestore
        .collection('transactions')
        .where('borrowerId', isEqualTo: userId)
        .where('status', whereIn: ['approved', 'picked_up', 'overdue'])
        .snapshots()
        .switchMap((snapshot) {
          final bookIds = snapshot.docs.map((doc) => doc.get('bookId') as String).toList();
          if (bookIds.isEmpty) return Stream.value([]);
          
          return _firestore
              .collection('books')
              .where(FieldPath.documentId, whereIn: bookIds)
              .snapshots()
              .map((snap) => snap.docs.map((doc) => Book.fromMap(doc.data(), doc.id)).toList());
        });
  }

  Future<void> addBook(Book book) async {
    await _firestore.collection('books').add(book.toMap());
  }

  Future<void> updateBookShareability(String bookId, bool isShareable) async {
    await _firestore.collection('books').doc(bookId).update({'isShareable': isShareable});
  }

  Future<void> removeBook(String bookId) async {
    final active = await _firestore
        .collection('transactions')
        .where('bookId', isEqualTo: bookId)
        .where('status', whereIn: ['requested', 'approved', 'picked_up', 'overdue'])
        .get();
    
    if (active.docs.isNotEmpty) {
      throw Exception('Cannot remove book while it is in an active transaction.');
    }
    
    await _firestore.collection('books').doc(bookId).delete();
  }
}

final bookshelfProvider = StreamProvider<List<BookshelfItem>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value([]);
  
  final repo = ref.watch(bookshelfRepositoryProvider);
  
  final ownedStream = repo.watchOwnedBooks(user.uid);
  final borrowedBooksStream = repo.watchBorrowedBooks(user.uid); 
  final lentTransactionsStream = repo.watchLentTransactions(user.uid); 

  return CombineLatestStream.combine3(
    ownedStream,
    borrowedBooksStream,
    lentTransactionsStream,
    (List<Book> owned, List<Book> borrowed, List<BookTransaction> lent) {
      final items = <BookshelfItem>[];

      for (var book in owned) {
        final activeLent = lent.where((t) => t.bookId == book.id).firstOrNull;
        items.add(BookshelfItem(
          book: book,
          transaction: activeLent,
          isLent: activeLent != null,
        ));
      }

      for (var book in borrowed) {
        items.add(BookshelfItem(
          book: book,
          isBorrowed: true,
        ));
      }

      return items;
    },
  );
});

final memberBooksProvider = StreamProvider.family<List<Book>, String>((ref, userId) {
  return ref.watch(bookshelfRepositoryProvider).watchOwnedBooks(userId);
});

class BookshelfItem {
  final Book book;
  final BookTransaction? transaction;
  final bool isBorrowed;
  final bool isLent;

  BookshelfItem({
    required this.book,
    this.transaction,
    this.isBorrowed = false,
    this.isLent = false,
  });
}
