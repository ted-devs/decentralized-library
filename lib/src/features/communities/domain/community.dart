class Community {
  final String id;
  final String name;
  final String description;
  final String adminId;
  final bool isPublic;
  final String? rules;
  final String country;
  final String city;
  final String? organization;

  final String? inviteCode;
  final DateTime? inviteExpiry;

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.adminId,
    required this.isPublic,
    required this.country,
    required this.city,
    this.rules,
    this.organization,
    this.inviteCode,
    this.inviteExpiry,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'adminId': adminId,
      'isPublic': isPublic,
      'rules': rules,
      'country': country,
      'city': city,
      'organization': organization,
      'inviteCode': inviteCode,
      'inviteExpiry': inviteExpiry?.toIso8601String(),
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
      country: map['country'] ?? '',
      city: map['city'] ?? '',
      organization: map['organization'],
      inviteCode: map['inviteCode'],
      inviteExpiry: map['inviteExpiry'] != null
          ? DateTime.parse(map['inviteExpiry'])
          : null,
    );
  }
}
