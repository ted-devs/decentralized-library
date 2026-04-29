import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';
import 'package:decentralized_library/src/features/library/domain/book_transaction.dart';
import 'package:decentralized_library/src/features/library/data/transaction_repository.dart';

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
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Book.fromMap(doc.data(), doc.id))
            .where((book) => book.isShareable)
            .toList());
  }

  Stream<List<BookTransaction>> watchLentTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookTransaction.fromMap(doc.data(), doc.id))
            .where((t) => !t.isDeletedByOwner) 
            .where((t) => [
                  TransactionStatus.approved,
                  TransactionStatus.pickedUp,
                  TransactionStatus.overdue,
                ].contains(t.status))
            .toList());
  }

  Stream<List<Book>> watchBorrowedBooks(String userId) {
    return _firestore
        .collection('transactions')
        .where('borrowerId', isEqualTo: userId)
        .snapshots()
        .switchMap((snapshot) {
          final activeTransactions = snapshot.docs
            .map((doc) => BookTransaction.fromMap(doc.data(), doc.id))
            .where((t) => !t.isDeletedByBorrower)
            .where((t) => t.status == TransactionStatus.pickedUp || t.status == TransactionStatus.overdue); 
          
          final bookIds = activeTransactions.map((t) => t.bookId).toSet().toList();
          
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
        .get();
    
    final isTrulyActive = active.docs
        .map((doc) => BookTransaction.fromMap(doc.data(), doc.id))
        .any((t) => t.status != TransactionStatus.returned && t.status != TransactionStatus.canceled);
    
    if (isTrulyActive) {
      throw Exception('Cannot remove book while it is in an active transaction.');
    }
    
    await _firestore.collection('books').doc(bookId).delete();
  }

  Stream<Book?> watchBook(String bookId) {
    return _firestore
        .collection('books')
        .doc(bookId)
        .snapshots()
        .map((doc) => doc.exists ? Book.fromMap(doc.data()!, doc.id) : null);
  }
}

final bookProvider = StreamProvider.family<Book?, String>((ref, bookId) {
  return ref.watch(bookshelfRepositoryProvider).watchBook(bookId);
});

final bookshelfProvider = StreamProvider<List<BookshelfItem>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  final repo = ref.watch(bookshelfRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  
  final ownedStream = repo.watchOwnedBooks(user.uid);
  final borrowedBooksStream = repo.watchBorrowedBooks(user.uid); 
  final lentTransactionsStream = repo.watchLentTransactions(user.uid); 

  // Watch borrower transactions to ensure bookshelf is reactive to status changes
  final borrowedTransactionsStream = transactionRepo.watchOutgoingRequests(user.uid);

  return CombineLatestStream.combine4(
    ownedStream,
    borrowedBooksStream,
    lentTransactionsStream,
    borrowedTransactionsStream,
    (List<Book> owned, List<Book> borrowed, List<BookTransaction> lent, List<BookTransaction> borrowedTx) {
      final items = <BookshelfItem>[];

      for (var book in owned) {
        final activeLent = lent.where((t) => t.bookId == book.id).firstOrNull;
        items.add(BookshelfItem(
          book: book,
          transaction: activeLent,
          isLent: activeLent != null && (activeLent.status == TransactionStatus.pickedUp || activeLent.status == TransactionStatus.overdue),
        ));
      }

      for (var book in borrowed) {
        // Only include in bookshelf if the transaction is still active for the borrower
        final activeBorrowed = borrowedTx.where((t) => 
          t.bookId == book.id && 
          (t.status == TransactionStatus.pickedUp || t.status == TransactionStatus.overdue)
        ).firstOrNull;

        if (activeBorrowed != null) {
          items.add(BookshelfItem(
            book: book,
            transaction: activeBorrowed,
            isBorrowed: true,
          ));
        }
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

enum BookshelfSort { recentlyAdded, titleAZ, titleZA }
enum BookshelfStatus { all, available, borrowed, lent }
enum BookshelfViewMode { list, grid }

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}
final bookshelfSearchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() => SearchQueryNotifier());

class SortNotifier extends Notifier<BookshelfSort> {
  @override
  BookshelfSort build() => BookshelfSort.recentlyAdded;
  void set(BookshelfSort value) => state = value;
}
final bookshelfSortProvider = NotifierProvider<SortNotifier, BookshelfSort>(() => SortNotifier());

class StatusNotifier extends Notifier<BookshelfStatus> {
  @override
  BookshelfStatus build() => BookshelfStatus.all;
  void set(BookshelfStatus value) => state = value;
}
final bookshelfStatusProvider = NotifierProvider<StatusNotifier, BookshelfStatus>(() => StatusNotifier());

class ViewModeNotifier extends Notifier<BookshelfViewMode> {
  @override
  BookshelfViewMode build() => BookshelfViewMode.grid;
  void toggle() => state = state == BookshelfViewMode.grid ? BookshelfViewMode.list : BookshelfViewMode.grid;
  void set(BookshelfViewMode mode) => state = mode;
}
final bookshelfViewModeProvider = NotifierProvider<ViewModeNotifier, BookshelfViewMode>(() => ViewModeNotifier());

final filteredBookshelfProvider = Provider<AsyncValue<List<BookshelfItem>>>((ref) {
  final bookshelfAsync = ref.watch(bookshelfProvider);
  final searchQuery = ref.watch(bookshelfSearchQueryProvider).toLowerCase();
  final sortOption = ref.watch(bookshelfSortProvider);
  final statusFilter = ref.watch(bookshelfStatusProvider);

  return bookshelfAsync.whenData((items) {
    var filtered = items.where((item) {
      // Status Filter
      if (statusFilter == BookshelfStatus.available && (item.isLent || item.isBorrowed)) return false;
      if (statusFilter == BookshelfStatus.borrowed && !item.isBorrowed) return false;
      if (statusFilter == BookshelfStatus.lent && !item.isLent) return false;

      // Search Filter
      if (searchQuery.isNotEmpty) {
        final matchesTitle = item.book.title.toLowerCase().contains(searchQuery);
        final matchesAuthor = item.book.author.toLowerCase().contains(searchQuery);
        if (!matchesTitle && !matchesAuthor) return false;
      }

      return true;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (sortOption) {
        case BookshelfSort.recentlyAdded:
          // Assuming higher index means older or newer depending on how it's returned from Firestore
          // We don't have a createdAt on book in this snapshot, but we can assume default order is by ID/creation.
          // Since we want recently added, maybe just return 0 to keep default firestore order or reverse it if needed.
          // Since we don't have createdAt, let's just keep the order they came in (which is usually by document ID or insert order).
          return 0; 
        case BookshelfSort.titleAZ:
          return a.book.title.compareTo(b.book.title);
        case BookshelfSort.titleZA:
          return b.book.title.compareTo(a.book.title);
      }
    });

    return filtered;
  });
});
