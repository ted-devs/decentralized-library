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
      appBar: AppBar(title: const Text('My Bookshelf')),
      floatingActionButton: ExpandableFab(
        distance: 60,
        children: [
          ActionButton(
            icon: const Icon(Icons.search),
            label: 'Search & Add',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddBookScreen()));
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
          // Search and Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search title or author...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => ref
                                  .read(bookshelfSearchQueryProvider.notifier)
                                  .set(''),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) => ref
                        .read(bookshelfSearchQueryProvider.notifier)
                        .set(value),
                  ),
                ),
                const SizedBox(width: 8),
                _BookshelfFilterButton(),
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
                        Icon(
                          Icons.library_books_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isNotEmpty ||
                                  statusFilter != BookshelfStatus.all
                              ? 'No books match your filters.'
                              : 'Your bookshelf is empty.',
                        ),
                        if (searchQuery.isEmpty &&
                            statusFilter == BookshelfStatus.all)
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AddBookScreen(),
                                ),
                              );
                            },
                            child: const Text('Add your first book'),
                          ),
                      ],
                    ),
                  );
                }

                final viewMode = ref.watch(bookshelfViewModeProvider);
                final gridSize = ref.watch(bookshelfGridSizeProvider);

                if (viewMode == BookshelfViewMode.grid) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridSize == BookshelfGridSize.small ? 4 : 3,
                      childAspectRatio: 0.65,
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
                      color: isLentOrNotShared
                          ? Colors.grey.withAlpha(50)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withAlpha(30)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                              ),
                            if (item.isBorrowed)
                              const Icon(
                                Icons.add_circle_outline,
                                color: Colors.green,
                              ),
                            if (item.isLent)
                              const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              )
                            else if (!book.isShareable)
                              const Icon(
                                Icons.visibility_off_outlined,
                                color: Colors.grey,
                              ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BookDetailsScreen(
                                book: book,
                                transaction: item.transaction,
                              ),
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

class _BookshelfFilterButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(bookshelfStatusProvider);
    final hasActiveFilters = statusFilter != BookshelfStatus.all;

    return IconButton.filledTonal(
      icon: Badge(
        isLabelVisible: hasActiveFilters,
        child: const Icon(Icons.tune_rounded),
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (context) => const _BookshelfFilterSheet(),
        );
      },
      tooltip: 'Filters',
    );
  }
}

class _BookshelfFilterSheet extends ConsumerWidget {
  const _BookshelfFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(bookshelfStatusProvider);
    final sortOption = ref.watch(bookshelfSortProvider);
    final viewMode = ref.watch(bookshelfViewModeProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Filters & Sorting', style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),

          Text('Status', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: BookshelfStatus.values.map((status) {
              return ChoiceChip(
                label: Text(
                  status.name[0].toUpperCase() + status.name.substring(1),
                ),
                selected: statusFilter == status,
                onSelected: (selected) {
                  if (selected)
                    ref.read(bookshelfStatusProvider.notifier).set(status);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          Text('Sort By', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          DropdownButtonFormField<BookshelfSort>(
            value: sortOption,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            items: const [
              DropdownMenuItem(
                value: BookshelfSort.recentlyAdded,
                child: Text('Recently Added'),
              ),
              DropdownMenuItem(
                value: BookshelfSort.titleAZ,
                child: Text('Title A-Z'),
              ),
              DropdownMenuItem(
                value: BookshelfSort.titleZA,
                child: Text('Title Z-A'),
              ),
            ],
            onChanged: (val) {
              if (val != null)
                ref.read(bookshelfSortProvider.notifier).set(val);
            },
          ),

          const SizedBox(height: 24),
          Text('View Mode', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          SegmentedButton<BookshelfViewMode>(
            segments: const [
              ButtonSegment(
                value: BookshelfViewMode.grid,
                label: Text('Grid'),
                icon: Icon(Icons.grid_view_rounded),
              ),
              ButtonSegment(
                value: BookshelfViewMode.list,
                label: Text('List'),
                icon: Icon(Icons.view_list_rounded),
              ),
            ],
            selected: {viewMode},
            onSelectionChanged: (newSelection) {
              ref
                  .read(bookshelfViewModeProvider.notifier)
                  .set(newSelection.first);
            },
          ),

          if (viewMode == BookshelfViewMode.grid) ...[
            const SizedBox(height: 24),
            Text('Grid Size', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            SegmentedButton<BookshelfGridSize>(
              segments: const [
                ButtonSegment(
                  value: BookshelfGridSize.small,
                  label: Text('Small'),
                  icon: Icon(Icons.grid_on_rounded),
                ),
                ButtonSegment(
                  value: BookshelfGridSize.medium,
                  label: Text('Medium'),
                  icon: Icon(Icons.grid_view_rounded),
                ),
              ],
              selected: {ref.watch(bookshelfGridSizeProvider)},
              onSelectionChanged: (newSelection) {
                ref
                    .read(bookshelfGridSizeProvider.notifier)
                    .set(newSelection.first);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _BookGridItem extends ConsumerWidget {
  final BookshelfItem item;

  const _BookGridItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = item.book;
    final isLentOrNotShared = item.isLent || !book.isShareable;
    final theme = Theme.of(context);
    final gridSize = ref.watch(bookshelfGridSizeProvider);
    final isSmall = gridSize == BookshelfGridSize.small;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                BookDetailsScreen(book: book, transaction: item.transaction),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
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
          // Gradient and Text Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 32, 8, 12),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(180),
                    Colors.black.withAlpha(220),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmall ? 11 : 12,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(100),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: isSmall ? 9 : 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Status Badges (Top)
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
          // Overdue Badge (Top Left)
          if (item.transaction?.isOverdue() == true)
            Positioned(
              top: 8,
              left: 8,
              child: _StatusBadge(
                icon: Icons.warning_amber_rounded,
                color: Colors.orange,
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
          BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 4),
        ],
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}
