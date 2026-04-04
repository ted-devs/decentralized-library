import 'package:cloud_firestore/cloud_firestore.dart';

enum MembershipStatus {
  pending,
  approved,
  rejected,
}

class Membership {
  final String id;
  final String communityId;
  final String userId;
  final MembershipStatus status;
  final DateTime joinedAt;

  Membership({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.status,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'communityId': communityId,
      'userId': userId,
      'status': status.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  factory Membership.fromMap(Map<String, dynamic> map, String id) {
    return Membership(
      id: id,
      communityId: map['communityId'] ?? '',
      userId: map['userId'] ?? '',
      status: MembershipStatus.values.byName(map['status'] ?? 'pending'),
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
    );
  }
}
