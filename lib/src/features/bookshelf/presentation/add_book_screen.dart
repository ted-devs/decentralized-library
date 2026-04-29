import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/bookshelf/application/google_books_service.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/book_details_screen.dart';
import 'package:decentralized_library/src/shared/utils/snackbar_utils.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key});

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _searchController = TextEditingController();
  List<Book> _searchResults = [];
  bool _isLoading = false;

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      final results = await ref.read(googleBooksServiceProvider).searchBooks(query, userId: user?.uid);
      setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Search failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addSelectedBook(Book book) async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      
      final bookToAdd = Book(
        id: '', 
        ownerId: user.uid,
        title: book.title,
        author: book.author,
        isbn: book.isbn,
        coverUrl: book.coverUrl,
        description: book.description,
        publisher: book.publisher,
        publishedYear: book.publishedYear,
        language: book.language,
      );

      await ref.read(bookshelfRepositoryProvider).addBook(bookToAdd);
      
      if (mounted) {
        AppSnackBar.show(context, 'Book added to your shelf!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Failed to add book: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a Book'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title, author, or ISBN',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _performSearch,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? const Center(child: Text('Search for a book to add it.'))
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final book = _searchResults[index];
                            return ListTile(
                              leading: book.coverUrl != null
                                  ? Image.network(book.coverUrl!, width: 40, height: 60, fit: BoxFit.cover)
                                  : const Icon(Icons.book),
                              title: Text(book.title),
                              subtitle: Text(book.author),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle),
                                color: Colors.blue,
                                onPressed: () => _addSelectedBook(book),
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BookDetailsScreen(book: book),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ManualAddBookScreen()),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Add Details Manually'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManualAddBookScreen extends ConsumerStatefulWidget {
  const ManualAddBookScreen({super.key});

  @override
  ConsumerState<ManualAddBookScreen> createState() => _ManualAddBookScreenState();
}

class _ManualAddBookScreenState extends ConsumerState<ManualAddBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _publisherController = TextEditingController();
  final _yearController = TextEditingController();
  final _languageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _submitManual() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final book = Book(
        id: '',
        ownerId: user.uid,
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        isbn: _isbnController.text.trim(),
        publisher: _publisherController.text.trim(),
        publishedYear: _yearController.text.trim(),
        language: _languageController.text.trim(),
      );

      await ref.read(bookshelfRepositoryProvider).addBook(book);

      if (mounted) {
        AppSnackBar.show(context, 'Book added to your shelf!');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Please enter title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(labelText: 'Author *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Please enter author' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _isbnController,
                decoration: const InputDecoration(labelText: 'ISBN', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _publisherController,
                decoration: const InputDecoration(labelText: 'Publisher', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _languageController,
                decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitManual,
                  child: _isLoading ? const CircularProgressIndicator() : const Text('Save Book'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
