import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';
import 'package:decentralized_library/src/features/library/domain/book_transaction.dart';
import 'package:decentralized_library/src/features/library/data/transaction_repository.dart';

class BookDetailsScreen extends ConsumerStatefulWidget {
  final Book book;
  final BookTransaction? transaction;
  const BookDetailsScreen({super.key, required this.book, this.transaction});

  @override
  ConsumerState<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends ConsumerState<BookDetailsScreen> {
  bool _isLoading = false;
  bool _isDescriptionExpanded = false;

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

  Future<void> _updateStatus(TransactionStatus status) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      switch (status) {
        case TransactionStatus.approved:
          await repo.approveRequest(widget.transaction!.id, 4); 
          break;
        case TransactionStatus.pickedUp:
          await repo.markAsPickedUp(widget.transaction!.id);
          break;
        case TransactionStatus.returned:
          await repo.markAsReturned(widget.transaction!.id);
          break;
        case TransactionStatus.canceled:
          await repo.cancelTransaction(widget.transaction!.id);
          break;
        default:
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to ${status.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestBorrow() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      await ref.read(transactionRepositoryProvider).requestBook(
        borrowerId: user.uid,
        bookId: widget.book.id,
        ownerId: widget.book.ownerId,
        communityId: 'default',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Borrow request sent!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addToShelf() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      
      final bookToAdd = Book(
        id: '', 
        ownerId: user.uid,
        title: widget.book.title,
        author: widget.book.author,
        isbn: widget.book.isbn,
        coverUrl: widget.book.coverUrl,
        description: widget.book.description,
        publisher: widget.book.publisher,
        publishedYear: widget.book.publishedYear,
        language: widget.book.language,
      );

      await ref.read(bookshelfRepositoryProvider).addBook(bookToAdd);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book added to your shelf!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add book: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isPreview = widget.book.id.isEmpty;
    final isOwner = !isPreview && widget.book.ownerId == user?.uid;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isPreview ? 'Preview Book' : 'Book Details'),
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
              const SizedBox(height: 12),
              if (isOwner) ...[
                if (widget.transaction!.status == TransactionStatus.requested) ...[
                  Row(
                    children: [
                      Expanded(child: ElevatedButton(onPressed: _isLoading ? null : () => _updateStatus(TransactionStatus.approved), child: const Text('Approve'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton(onPressed: _isLoading ? null : () => _updateStatus(TransactionStatus.canceled), child: const Text('Deny'))),
                    ],
                  ),
                ],
                if (widget.transaction!.status == TransactionStatus.approved)
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isLoading ? null : () => _updateStatus(TransactionStatus.pickedUp), child: const Text('Mark as Picked Up'))),
                if (widget.transaction!.status == TransactionStatus.pickedUp)
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isLoading ? null : () => _updateStatus(TransactionStatus.returned), child: const Text('Mark as Returned'))),
              ] else ...[
                if (widget.transaction!.status == TransactionStatus.requested)
                  SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _isLoading ? null : () => _updateStatus(TransactionStatus.canceled), child: const Text('Cancel Request'))),
              ],
              const SizedBox(height: 24),
            ],
            if (isPreview) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addToShelf,
                  icon: const Icon(Icons.add_to_photos_rounded),
                  label: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Add to My Shelf'),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (!isPreview && !isOwner && widget.transaction == null && widget.book.isShareable) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _requestBorrow,
                  icon: const Icon(Icons.send_rounded),
                  label: _isLoading ? const CircularProgressIndicator() : const Text('Request to Borrow'),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text('About this book', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final description = widget.book.description ?? 'No description available.';
                final canToggle = description.length > 200;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      tween: Tween<double>(begin: 0, end: _isDescriptionExpanded ? 1 : 0),
                      builder: (context, value, child) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          constraints: BoxConstraints(
                            maxHeight: _isDescriptionExpanded ? 1000 : 120,
                          ),
                          child: ShaderMask(
                            shaderCallback: (rect) {
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black, 
                                  Color.lerp(Colors.transparent, Colors.black, value)!
                                ],
                                stops: const [0.7, 1.0],
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Text(
                              description, 
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        );
                      },
                    ),
                    if (canToggle)
                      TextButton(
                        onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                        child: Text(_isDescriptionExpanded ? 'Read Less' : 'Read More'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
