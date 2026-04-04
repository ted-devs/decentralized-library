import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/add_book_screen.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/book_details_screen.dart';

class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookshelfAsync = ref.watch(bookshelfProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookshelf'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddBookScreen()),
              );
            },
          ),
        ],
      ),
      body: bookshelfAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Your bookshelf is empty.'),
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

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final book = item.book;

              return Card(
                elevation: 0,
                color: item.isLent ? Colors.grey.withAlpha(50) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.withAlpha(30)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: book.coverUrl != null
                        ? Opacity(
                            opacity: item.isLent ? 0.5 : 1.0,
                            child: Image.network(
                              book.coverUrl!,
                              width: 50,
                              height: 75,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, _) => Container(
                                width: 50,
                                height: 75,
                                color: Colors.grey[300],
                                child: const Icon(Icons.book),
                              ),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 75,
                            color: Colors.grey[300],
                            child: const Icon(Icons.book),
                          ),
                  ),
                  title: Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: item.isLent ? Colors.grey : null,
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
                      if (item.isBorrowed)
                        const Icon(Icons.add_circle_outline, color: Colors.green),
                      if (item.isLent)
                        const Icon(Icons.remove_circle_outline, color: Colors.red),
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
    );
  }
}
