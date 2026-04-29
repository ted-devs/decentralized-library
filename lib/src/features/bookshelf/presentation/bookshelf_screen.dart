import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/add_book_screen.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/book_details_screen.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/widgets/book_cover.dart';
import 'package:decentralized_library/src/shared/widgets/expandable_fab.dart';

class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookshelfAsync = ref.watch(filteredBookshelfProvider);
    final searchQuery = ref.watch(bookshelfSearchQueryProvider);
    final sortOption = ref.watch(bookshelfSortProvider);
    final statusFilter = ref.watch(bookshelfStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookshelf'),
        actions: [
          IconButton(
            icon: Icon(
              ref.watch(bookshelfViewModeProvider) == BookshelfViewMode.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
            onPressed: () => ref.read(bookshelfViewModeProvider.notifier).toggle(),
            tooltip: 'Toggle view mode',
          ),
        ],
      ),
      floatingActionButton: ExpandableFab(
        distance: 60,
        children: [
          ActionButton(
            icon: const Icon(Icons.search),
            label: 'Search & Add',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddBookScreen()),
              );
            },
          ),
          ActionButton(
            icon: const Icon(Icons.edit),
            label: 'Add manually',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManualAddBookScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search title or author...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => ref.read(bookshelfSearchQueryProvider.notifier).set(''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) => ref.read(bookshelfSearchQueryProvider.notifier).set(value),
            ),
          ),
          
          // Filters and Sorts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Status Dropdown / Chips
                const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<BookshelfStatus>(
                  value: statusFilter,
                  underline: const SizedBox(),
                  onChanged: (BookshelfStatus? newValue) {
                    if (newValue != null) {
                      ref.read(bookshelfStatusProvider.notifier).set(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: BookshelfStatus.all, child: Text('All')),
                    DropdownMenuItem(value: BookshelfStatus.available, child: Text('Available')),
                    DropdownMenuItem(value: BookshelfStatus.borrowed, child: Text('Borrowed')),
                    DropdownMenuItem(value: BookshelfStatus.lent, child: Text('Lent')),
                  ],
                ),
                const SizedBox(width: 16),
                const Text('Sort: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<BookshelfSort>(
                  value: sortOption,
                  underline: const SizedBox(),
                  onChanged: (BookshelfSort? newValue) {
                    if (newValue != null) {
                      ref.read(bookshelfSortProvider.notifier).set(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: BookshelfSort.recentlyAdded, child: Text('Recently Added')),
                    DropdownMenuItem(value: BookshelfSort.titleAZ, child: Text('Title A-Z')),
                    DropdownMenuItem(value: BookshelfSort.titleZA, child: Text('Title Z-A')),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),

          // Book List
          Expanded(
            child: bookshelfAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(searchQuery.isNotEmpty || statusFilter != BookshelfStatus.all 
                          ? 'No books match your filters.' 
                          : 'Your bookshelf is empty.'),
                        if (searchQuery.isEmpty && statusFilter == BookshelfStatus.all)
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AddBookScreen()),
                              );
                            },
                            child: const Text('Add your first book'),
                          ),
                      ],
                    ),
                  );
                }

                final viewMode = ref.watch(bookshelfViewModeProvider);

                if (viewMode == BookshelfViewMode.grid) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.58,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _BookGridItem(item: item);
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final book = item.book;
                    final isLentOrNotShared = item.isLent || !book.isShareable;

                    return Card(
                      elevation: 0,
                      color: isLentOrNotShared ? Colors.grey.withAlpha(50) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withAlpha(30)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Opacity(
                            opacity: isLentOrNotShared ? 0.5 : 1.0,
                            child: BookCover(
                              url: book.coverUrl,
                              useCache: true,
                            ),
                          ),
                        ),
                        title: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isLentOrNotShared ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.transaction?.isOverdue() == true)
                              const Padding(
                                padding: EdgeInsets.only(right: 4.0),
                                child: Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange, size: 20),
                              ),
                            if (item.isBorrowed)
                              const Icon(Icons.add_circle_outline,
                                  color: Colors.green),
                            if (item.isLent)
                              const Icon(Icons.remove_circle_outline,
                                  color: Colors.red)
                            else if (!book.isShareable)
                              const Icon(Icons.visibility_off_outlined,
                                  color: Colors.grey),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BookDetailsScreen(book: book, transaction: item.transaction),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookGridItem extends StatelessWidget {
  final BookshelfItem item;

  const _BookGridItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final book = item.book;
    final isLentOrNotShared = item.isLent || !book.isShareable;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookDetailsScreen(book: book, transaction: item.transaction),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Opacity(
                      opacity: isLentOrNotShared ? 0.6 : 1.0,
                      child: BookCover(
                        url: book.coverUrl,
                        width: double.infinity,
                        height: double.infinity,
                        useCache: true,
                      ),
                    ),
                  ),
                ),
                // Status Badges
                if (item.isLent)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _StatusBadge(
                      icon: Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                  )
                else if (item.isBorrowed)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _StatusBadge(
                      icon: Icons.add_circle_outline,
                      color: Colors.green,
                    ),
                  )
                else if (!book.isShareable)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _StatusBadge(
                      icon: Icons.visibility_off_outlined,
                      color: Colors.grey,
                    ),
                  ),
                if (item.transaction?.isOverdue() == true)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _StatusBadge(
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isLentOrNotShared ? Colors.grey : null,
            ),
          ),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StatusBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(200),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 4,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}
