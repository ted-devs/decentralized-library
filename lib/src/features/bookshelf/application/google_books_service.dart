import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/book.dart';

final googleBooksServiceProvider = Provider((ref) => GoogleBooksService());

class GoogleBooksService {
  static const String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';

  Future<List<Book>> searchBooks(String query, {String? userId}) async {
    if (query.isEmpty) return [];
    
    final response = await http.get(Uri.parse('$_baseUrl?q=$query&maxResults=10'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['items'] as List?;
      if (items == null) return [];

      return items.map((item) {
        final volumeInfo = item['volumeInfo'];
        final industryIdentifiers = volumeInfo['industryIdentifiers'] as List?;
        final isbn = industryIdentifiers?.firstWhere(
          (id) => id['type'] == 'ISBN_13',
          orElse: () => industryIdentifiers.firstWhere(
            (id) => id['type'] == 'ISBN_10',
            orElse: () => null,
          ),
        )?['identifier'];

        return Book(
          id: '', 
          ownerId: userId ?? '',
          title: volumeInfo['title'] ?? 'Unknown',
          author: (volumeInfo['authors'] as List?)?.join(', ') ?? 'Unknown',
          isbn: isbn,
          coverUrl: volumeInfo['imageLinks']?['thumbnail'],
          description: volumeInfo['description'],
          publisher: volumeInfo['publisher'],
          publishedYear: volumeInfo['publishedDate'],
          language: volumeInfo['language'],
        );
      }).toList();
    } else {
      throw Exception('Failed to search books from Google API');
    }
  }
}
