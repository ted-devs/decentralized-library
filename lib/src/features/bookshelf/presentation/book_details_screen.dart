import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:decentralized_library/src/features/auth/domain/app_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';
import 'package:decentralized_library/src/features/library/domain/book_transaction.dart';
import 'package:decentralized_library/src/features/library/data/transaction_repository.dart';
import 'package:decentralized_library/src/features/library/application/active_transaction_service.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/widgets/book_cover.dart';
import 'package:decentralized_library/src/features/communities/presentation/user_profile_screen.dart';

class BookDetailsScreen extends ConsumerStatefulWidget {
  final Book book;
  final BookTransaction? transaction;
  const BookDetailsScreen({super.key, required this.book, this.transaction});

  @override
  ConsumerState<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends ConsumerState<BookDetailsScreen> {
  bool _isLoading = false;
  int _selectedDuration = 2; // Default to 2 weeks
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
        durationWeeks: _selectedDuration,
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

  Future<void> _showApprovalDialog() async {
    if (widget.transaction == null) return;
    int duration = widget.transaction!.durationWeeks;
    final confirmed = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Approve Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The borrower requested to keep this book for:'),
              const SizedBox(height: 4),
              Text(
                '${widget.transaction!.durationWeeks} ${widget.transaction!.durationWeeks == 1 ? 'week' : 'weeks'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'You can reduce this duration if needed:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [1, 2, 3, 4]
                    .where((w) => w <= widget.transaction!.durationWeeks)
                    .map((w) {
                  return ChoiceChip(
                    label: Text('$w ${w == 1 ? 'wk' : 'wks'}'),
                    selected: duration == w,
                    onSelected: (selected) {
                      if (selected) setDialogState(() => duration = w);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, duration),
              child: const Text('Approve'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != null) {
      setState(() => _isLoading = true);
      try {
        await ref.read(transactionRepositoryProvider).approveRequest(
              widget.transaction!.id,
              confirmed,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request approved!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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

  String _getStatusLabel(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.requested: return 'Request Pending';
      case TransactionStatus.approved: return 'Awaiting Pickup';
      case TransactionStatus.pickedUp: return 'On Loan';
      case TransactionStatus.returned: return 'Returned';
      case TransactionStatus.canceled: return 'Canceled';
      case TransactionStatus.overdue: return 'Overdue';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isPreview = widget.book.id.isEmpty;
    final isOwner = !isPreview && widget.book.ownerId == user?.uid;
    final theme = Theme.of(context);

    // Watch the book for real-time updates
    final bookAsync = !isPreview
        ? ref.watch(bookProvider(widget.book.id))
        : AsyncValue.data(widget.book);

    // Watch the transaction for real-time updates if applicable
    final transactionAsync = widget.transaction != null
        ? ref.watch(transactionProvider(widget.transaction!.id))
        : const AsyncValue<BookTransaction?>.data(null);

    return bookAsync.when(
      data: (liveBook) {
        final book = liveBook ?? widget.book;

        return transactionAsync.when(
          data: (liveTx) {
            final transaction = liveTx ?? widget.transaction;

            return Scaffold(
              appBar: AppBar(
                title: Text(isPreview ? 'Preview Book' : 'Book Details'),
                actions: [
                  if (isOwner && transaction == null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _isLoading ? null : _removeBook,
                    ),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BookCover(
                            url: book.coverUrl,
                            width: 100,
                            height: 150,
                            useCache: isOwner,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'by ${book.author}',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 12),
                              if (book.publishedYear != null)
                                Text(
                                  'Published: ${book.publishedYear!.split('-')[0]}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              if (book.publisher != null)
                                Text(
                                  'Publisher: ${book.publisher}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              if (book.language != null)
                                Text(
                                  'Language: ${book.language}',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isOwner) ...[
                      SwitchListTile(
                        value: book.isShareable,
                        onChanged: _isLoading || transaction != null
                            ? null
                            : _toggleShareability,
                        title: const Text('Available for sharing'),
                        subtitle: transaction != null
                            ? const Text('Cannot change while lent out')
                            : null,
                      ),
                      const Divider(),
                    ],
                    if (transaction != null) ...[
                      Text('Transaction Status',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Card(
                        color: theme.colorScheme.primaryContainer.withAlpha(50),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Status: ${_getStatusLabel(transaction.status)}'
                                      .toUpperCase(),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary)),
                              const Divider(height: 24),
                              const Text('Coordination Details:',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Builder(builder: (context) {
                                final status = transaction.status;

                                // Active statuses where coordination is needed
                                final activeStatuses = [
                                  TransactionStatus.requested,
                                  TransactionStatus.approved,
                                  TransactionStatus.pickedUp,
                                  TransactionStatus.overdue,
                                ];

                                if (!activeStatuses.contains(status)) {
                                  String message =
                                      'This transaction is complete. Coordination info is no longer available.';
                                  if (status == TransactionStatus.canceled) {
                                    message =
                                        'This request has been cancelled. Coordination info is no longer available.';
                                  }
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(message),
                                  );
                                }

                                final canViewProfile = isOwner ||
                                    (status == TransactionStatus.approved ||
                                        status == TransactionStatus.pickedUp ||
                                        status == TransactionStatus.overdue);

                                if (!canViewProfile && !isOwner) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(
                                        'Once the owner approves your request, you will be able to view their profile to coordinate the exchange.'),
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                        'Coordinate the physical exchange via profile contact info.'),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                              final userIdToView = isOwner
                                                  ? transaction.borrowerId
                                                  : transaction.ownerId;
                                              setState(() => _isLoading = true);
                                              try {
                                                final doc = await FirebaseFirestore
                                                    .instance
                                                    .collection('users')
                                                    .doc(userIdToView)
                                                    .get();
                                                if (mounted) {
                                                  if (doc.exists &&
                                                      doc.data() != null) {
                                                    final userProfile =
                                                        AppUser.fromMap(
                                                            doc.data()!, doc.id);
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            UserProfileScreen(
                                                          user: userProfile,
                                                          membership: null,
                                                          prefillBookTitle:
                                                              book.title,
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(const SnackBar(
                                                            content: Text(
                                                                'User profile not found.')));
                                                  }
                                                }
                                              } catch (e) {
                                                if (mounted)
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(
                                                              'Error loading profile: $e')));
                                              } finally {
                                                if (mounted)
                                                  setState(() => _isLoading = false);
                                              }
                                            },
                                      icon: _isLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : const Icon(Icons.person_pin_rounded,
                                              size: 18),
                                      label: Text(isOwner
                                          ? 'View Borrower Profile'
                                          : 'View Owner Profile'),
                                    ),
                                  ],
                                );
                              }),
                              if (transaction.pickedUpDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Due: ${transaction.pickedUpDate!.add(Duration(days: transaction.durationWeeks * 7)).toLocal().toString().split(' ')[0]}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isOwner) ...[
                        if (transaction.status ==
                            TransactionStatus.requested) ...[
                          Row(
                            children: [
                              Expanded(
                                  child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _showApprovalDialog,
                                      child: const Text('Approve'))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: OutlinedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _updateStatus(
                                              TransactionStatus.canceled),
                                  child: const Text('Deny'))),
                            ],
                          ),
                        ],
                        if (transaction.status ==
                            TransactionStatus.approved) ...[
                          Row(
                            children: [
                              Expanded(
                                  child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _updateStatus(
                                              TransactionStatus.pickedUp),
                                  child: const Text('Mark as Picked Up'))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: OutlinedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _updateStatus(
                                              TransactionStatus.canceled),
                                  child: const Text('Cancel Request'))),
                            ],
                          ),
                        ],
                        if (transaction.status ==
                            TransactionStatus.pickedUp)
                          SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                  onPressed: _isLoading
                                  ? null
                                  : () =>
                                      _updateStatus(TransactionStatus.returned),
                              child: const Text('Mark as Returned'))),
                      ] else ...[
                        if (transaction.status ==
                                TransactionStatus.requested ||
                            transaction.status ==
                                TransactionStatus.approved)
                          SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                  onPressed: _isLoading
                                  ? null
                                  : () =>
                                      _updateStatus(TransactionStatus.canceled),
                              child: const Text('Cancel Request'))),
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
                          label: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Add to My Shelf'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (!isPreview &&
                        !isOwner &&
                        transaction == null &&
                        book.isShareable) ...[
                      Consumer(
                        builder: (context, ref, child) {
                          final user = ref.watch(authStateProvider).value;
                          final activeTxAsync =
                              ref.watch(activeTransactionForBookProvider((
                            userId: user?.uid ?? '',
                            bookId: book.id,
                          )));
                          final confirmedTxAsync = ref
                              .watch(confirmedTransactionForBookProvider(book.id));

                          return activeTxAsync.when(
                            data: (activeTx) {
                              // 1. If the current user has an active request, show their status.
                              if (activeTx != null) {
                                String buttonLabel = 'Request Pending';
                                if (activeTx.status == TransactionStatus.approved)
                                  buttonLabel = 'Awaiting Pickup';
                                if (activeTx.status == TransactionStatus.pickedUp)
                                  buttonLabel = 'On Loan';

                                return SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        null, // Disabled because I already have an active session
                                    icon: const Icon(Icons.hourglass_empty_rounded),
                                    label: Text(buttonLabel),
                                  ),
                                );
                              }

                              // 2. If NO personal request, check if SOMEONE ELSE has a confirmed transaction.
                              return confirmedTxAsync.when(
                                data: (confirmedTx) {
                                  if (confirmedTx != null) {
                                    return SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            null, // Disabled because someone else has it
                                        icon: const Icon(Icons.lock_clock_rounded),
                                        label: const Text('Already Borrowed'),
                                      ),
                                    );
                                  }

                                  // 3. Otherwise, I can request it.
                                  return Column(
                                    children: [
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Borrowing Duration',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [1, 2, 3, 4].map((weeks) {
                                          final isSelected =
                                              _selectedDuration == weeks;
                                          return ChoiceChip(
                                            label: Text(
                                                '$weeks ${weeks == 1 ? 'wk' : 'wks'}'),
                                            selected: isSelected,
                                            selectedColor: theme
                                                .colorScheme.primaryContainer,
                                            onSelected: (selected) {
                                              if (selected) {
                                                setState(() =>
                                                    _selectedDuration = weeks);
                                              }
                                            },
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 50,
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              _isLoading ? null : _requestBorrow,
                                          icon: const Icon(Icons.send_rounded),
                                          label: _isLoading
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2))
                                              : const Text('Request to Borrow'),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                                loading: () => const SizedBox(
                                    height: 50,
                                    child:
                                        Center(child: CircularProgressIndicator())),
                                error: (_, __) => const SizedBox.shrink(),
                              );
                            },
                            loading: () => const SizedBox(
                                height: 50,
                                child: Center(child: CircularProgressIndicator())),
                            error: (_, __) => const SizedBox.shrink(),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text('About this book',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final description =
                            book.description ?? 'No description available.';
                        final canToggle = description.length > 200;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              tween: Tween<double>(
                                  begin: 0, end: _isDescriptionExpanded ? 1 : 0),
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
                                          Color.lerp(
                                              Colors.transparent, Colors.black, value)!
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
                                onPressed: () => setState(() =>
                                    _isDescriptionExpanded =
                                        !_isDescriptionExpanded),
                                child: Text(_isDescriptionExpanded
                                    ? 'Read Less'
                                    : 'Read More'),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error loading transaction: $e')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error loading book: $e')),
      ),
    );
  }
}
