import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/auth/domain/app_user.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';
import 'package:decentralized_library/src/features/library/domain/book_transaction.dart';

class BookDetailsScreen extends ConsumerStatefulWidget {
  final Book book;
  final BookTransaction? transaction;
  const BookDetailsScreen({super.key, required this.book, this.transaction});

  @override
  ConsumerState<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends ConsumerState<BookDetailsScreen> {
  bool _isLoading = false;

  Future<void> _toggleShareability(bool value) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(bookshelfRepositoryProvider).updateBookShareability(widget.book.id, value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeBook() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Book?'),
        content: const Text('Are you sure you want to remove this book from your shelf?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(bookshelfRepositoryProvider).removeBook(widget.book.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book removed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isOwner = widget.book.ownerId == user?.uid;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
        actions: [
          if (isOwner && widget.transaction == null)
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _isLoading ? null : _removeBook),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.book.coverUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(widget.book.coverUrl!, width: 100, height: 150, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 100,
                    height: 150,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.book, size: 50),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.book.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('by ${widget.book.author}', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
                      const SizedBox(height: 12),
                      if (widget.book.publishedYear != null)
                        Text('Published: ${widget.book.publishedYear}', style: theme.textTheme.bodySmall),
                      if (widget.book.language != null)
                        Text('Language: ${widget.book.language}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isOwner) ...[
              SwitchListTile(
                value: widget.book.isShareable,
                onChanged: _isLoading || widget.transaction != null ? null : _toggleShareability,
                title: const Text('Available for sharing'),
                subtitle: widget.transaction != null ? const Text('Cannot change while lent out') : null,
              ),
              const Divider(),
            ],
            if (widget.transaction != null) ...[
              Text('Transaction Status', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                color: theme.colorScheme.primaryContainer.withAlpha(50),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${widget.transaction!.status.name.toUpperCase()}', 
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      const SizedBox(height: 8),
                      Text(isOwner ? 'Lent to: Another Member' : 'Borrowed from: Owner'),
                      if (widget.transaction!.pickedUpDate != null)
                        Text('Due: ${widget.transaction!.pickedUpDate!.add(Duration(days: widget.transaction!.durationWeeks * 7)).toLocal().toString().split(' ')[0]}'),
                      const SizedBox(height: 12),
                      const Text('Contact Information:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Email: member@example.com (Mocked)'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text('About this book', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.book.description ?? 'No description available.', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
