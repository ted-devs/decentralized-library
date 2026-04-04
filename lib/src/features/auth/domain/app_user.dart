class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String city;
  final String country;
  final bool isPro;
  final bool isAdmin;
  final bool publicContactInfo;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.city,
    required this.country,
    this.isPro = false,
    this.isAdmin = false,
    this.publicContactInfo = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'city': city,
      'country': country,
      'isPro': isPro,
      'isAdmin': isAdmin,
      'publicContactInfo': publicContactInfo,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      city: map['city'] ?? '',
      country: map['country'] ?? '',
      isPro: map['isPro'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      publicContactInfo: map['publicContactInfo'] ?? false,
    );
  }
}
