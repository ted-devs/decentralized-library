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

        final active = requests.where((t) => [
          TransactionStatus.requested,
          TransactionStatus.approved,
          TransactionStatus.pickedUp,
          TransactionStatus.overdue,
        ].contains(t.status)).toList();
        
        final inactive = requests.where((t) => [
          TransactionStatus.returned,
          TransactionStatus.canceled,
        ].contains(t.status)).toList();

        return ListView(
          children: [
            if (active.isNotEmpty) ...[
              const _SectionHeader(title: 'Active Transactions'),
              ...active.map((t) => _TransactionTile(transaction: t)),
            ],
            if (inactive.isNotEmpty) ...[
              _SectionHeader(
                title: 'Past Transactions',
                onAction: () => _clearHistory(context, ref, inactive, 'lending'),
                actionLabel: 'CLEAR ALL',
              ),
              ...inactive.map((t) => _TransactionTile(transaction: t)),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref, List<BookTransaction> items, String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: Text('This will remove all ${items.length} past transactions from your view. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await ref.read(transactionRepositoryProvider).deleteMultipleTransactions(items, user.uid);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('History cleared.')),
          );
        }
      }
    }
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

        final active = requests.where((t) => [
          TransactionStatus.requested,
          TransactionStatus.approved,
          TransactionStatus.pickedUp,
          TransactionStatus.overdue,
        ].contains(t.status)).toList();
        
        final inactive = requests.where((t) => [
          TransactionStatus.returned,
          TransactionStatus.canceled,
        ].contains(t.status)).toList();

        return ListView(
          children: [
            if (active.isNotEmpty) ...[
              const _SectionHeader(title: 'Active Transactions'),
              ...active.map((t) => _TransactionTile(transaction: t)),
            ],
            if (inactive.isNotEmpty) ...[
              _SectionHeader(
                title: 'Past Transactions',
                onAction: () => _clearHistory(context, ref, inactive, 'borrowing'),
                actionLabel: 'CLEAR ALL',
              ),
              ...inactive.map((t) => _TransactionTile(transaction: t)),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref, List<BookTransaction> items, String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: Text('This will remove all ${items.length} past transactions from your view. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await ref.read(transactionRepositoryProvider).deleteMultipleTransactions(items, user.uid);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('History cleared.')),
          );
        }
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _SectionHeader({
    required this.title,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: theme.colorScheme.surfaceVariant.withAlpha(50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          if (onAction != null && actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                actionLabel!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
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

    String _getStatusLabel(TransactionStatus status) {
      switch (status) {
        case TransactionStatus.requested: return 'Request Pending';
        case TransactionStatus.approved: return 'Awaiting Pickup';
        case TransactionStatus.pickedUp: return 'On Loan';
        case TransactionStatus.returned: return 'Returned';
        case TransactionStatus.canceled: return 'Request Canceled';
        case TransactionStatus.overdue: return 'Overdue';
      }
    }

    Future<void> _showDeleteConfirmation(BuildContext context) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Request?'),
          content: const Text('Are you sure you want to remove this request from your history? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final user = ref.read(authStateProvider).value;
        if (user != null) {
          await ref.read(transactionRepositoryProvider).deleteTransaction(transaction.id, user.uid);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('History item removed.')),
            );
          }
        }
      }
    }

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
          subtitle: Text('Status: ${_getStatusLabel(transaction.status)}'),
          trailing: (transaction.status == TransactionStatus.canceled || 
                     transaction.status == TransactionStatus.returned)
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _showDeleteConfirmation(context),
              )
            : const Icon(Icons.chevron_right),
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
