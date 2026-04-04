class Community {
  final String id;
  final String name;
  final String description;
  final String adminId;
  final bool isPublic;
  final String? rules;

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.adminId,
    required this.isPublic,
    this.rules,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'adminId': adminId,
      'isPublic': isPublic,
      'rules': rules,
    };
  }

  factory Community.fromMap(Map<String, dynamic> map, String id) {
    return Community(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      adminId: map['adminId'] ?? '',
      isPublic: map['isPublic'] ?? true,
      rules: map['rules'],
    );
  }
}
