import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/transaction_repository.dart';
import '../domain/book_transaction.dart';

/// Provider to watch the active transaction for a specific user and book.
/// Used to prevent duplicate borrow requests and determine screen state.
final activeTransactionForBookProvider = StreamProvider.family<BookTransaction?, ({String userId, String bookId})>((ref, arg) {
  return ref.watch(transactionRepositoryProvider).watchActiveTransactionForBook(arg.userId, arg.bookId);
});

final confirmedTransactionForBookProvider = StreamProvider.family<BookTransaction?, String>((ref, bookId) {
  return ref.watch(transactionRepositoryProvider).watchAnyConfirmedTransactionForBook(bookId);
});
