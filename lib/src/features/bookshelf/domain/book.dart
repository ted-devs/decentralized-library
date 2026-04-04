class Book {
  final String id;
  final String ownerId;
  final String title;
  final String author;
  final String? isbn;
  final String? coverUrl;
  final String? description;
  final String? publisher;
  final String? publishedYear;
  final String? language;
  final bool isShareable;

  Book({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.author,
    this.isbn,
    this.coverUrl,
    this.description,
    this.publisher,
    this.publishedYear,
    this.language,
    this.isShareable = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'author': author,
      'isbn': isbn,
      'coverUrl': coverUrl,
      'description': description,
      'publisher': publisher,
      'publishedYear': publishedYear,
      'language': language,
      'isShareable': isShareable,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map, String id) {
    return Book(
      id: id,
      ownerId: map['ownerId'] ?? '',
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      isbn: map['isbn'],
      coverUrl: map['coverUrl'],
      description: map['description'],
      publisher: map['publisher'],
      publishedYear: map['publishedYear'],
      language: map['language'],
      isShareable: map['isShareable'] ?? true,
    );
  }
}
