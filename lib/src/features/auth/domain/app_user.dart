import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<String> pinnedCommunities;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.city,
    required this.country,
    required this.createdAt,
    this.isPro = false,
    this.isAdmin = false,
    this.publicContactInfo = false,
    this.pinnedCommunities = const [],
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
      'pinnedCommunities': pinnedCommunities,
      'createdAt': Timestamp.fromDate(createdAt),
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
      pinnedCommunities: List<String>.from(map['pinnedCommunities'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
