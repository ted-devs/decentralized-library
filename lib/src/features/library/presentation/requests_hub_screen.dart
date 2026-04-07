import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/library/data/transaction_repository.dart';
import 'package:decentralized_library/src/features/library/domain/book_transaction.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/book_details_screen.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/widgets/book_cover.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final incomingRequestsProvider = StreamProvider<List<BookTransaction>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref
      .watch(transactionRepositoryProvider)
      .watchIncomingRequests(user.uid);
});

final outgoingRequestsProvider = StreamProvider<List<BookTransaction>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref
      .watch(transactionRepositoryProvider)
      .watchOutgoingRequests(user.uid);
});

// A provider to fetch a single book by ID from Firestore (or local bookshelf)
final bookProvider = StreamProvider.family<Book?, String>((ref, bookId) {
  return FirebaseFirestore.instance
      .collection('books')
      .doc(bookId)
      .snapshots()
      .map((snap) => snap.exists ? Book.fromMap(snap.data()!, snap.id) : null);
});

class RequestsHubScreen extends ConsumerWidget {
  const RequestsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          bottom: TabBar(
            tabs: [
              Tab(
                child: Badge(
                  isLabelVisible: ref.watch(incomingRequestsProvider).value?.isNotEmpty ?? false,
                  child: const Text('To Me (Lending)'),
                ),
              ),
              Tab(
                child: Badge(
                  isLabelVisible: ref.watch(outgoingRequestsProvider).value?.isNotEmpty ?? false,
                  child: const Text('By Me (Borrowing)'),
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_IncomingRequestsView(), _OutgoingRequestsView()],
        ),
      ),
    );
  }
}

class _IncomingRequestsView extends ConsumerWidget {
  const _IncomingRequestsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider);

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty)
          return const Center(child: Text('No incoming requests.'));

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _TransactionTile(transaction: request);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _OutgoingRequestsView extends ConsumerWidget {
  const _OutgoingRequestsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(outgoingRequestsProvider);

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty)
          return const Center(child: Text('No outgoing requests.'));

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _TransactionTile(transaction: request);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final BookTransaction transaction;
  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We need to fetch the book details to show the title
    final bookAsync = ref.watch(bookProvider(transaction.bookId));

    return bookAsync.when(
      data: (book) {
        if (book == null) return const ListTile(title: Text('Book not found'));

        return ListTile(
          leading: BookCover(
            url: book.coverUrl,
            width: 40,
            height: 60,
            useCache: true,
          ),
          title: Text(book.title),
          subtitle: Text('Status: ${transaction.status.name.toUpperCase()}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    BookDetailsScreen(book: book, transaction: transaction),
              ),
            );
          },
        );
      },
      loading: () => const ListTile(title: Text('Loading book...')),
      error: (e, st) => ListTile(title: Text('Error: $e')),
    );
  }
}
