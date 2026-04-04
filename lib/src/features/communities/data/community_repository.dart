import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/community.dart';
import '../domain/membership.dart';


final communityRepositoryProvider = Provider((ref) => CommunityRepository(FirebaseFirestore.instance));

class CommunityRepository {
  final FirebaseFirestore _firestore;
  CommunityRepository(this._firestore);

  Future<String> createCommunity(Community community) async {
    final docRef = await _firestore.collection('communities').add(community.toMap());
    
    // Auto-approve admin as member
    await _firestore.collection('memberships').add({
      'communityId': docRef.id,
      'userId': community.adminId,
      'status': MembershipStatus.approved.name,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    
    return docRef.id;
  }

  Stream<List<Community>> watchAllCommunities() {
    return _firestore.collection('communities').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Community.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<Membership>> watchUserMemberships(String userId) {
    return _firestore
        .collection('memberships')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Membership.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Membership>> watchCommunityMembers(String communityId) {
    return _firestore
        .collection('memberships')
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: MembershipStatus.approved.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Membership.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Membership>> watchPendingRequests(String communityId) {
    return _firestore
        .collection('memberships')
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: MembershipStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Membership.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> requestToJoin(String userId, Community community) async {
    await _firestore.collection('memberships').add({
      'communityId': community.id,
      'userId': userId,
      'status': MembershipStatus.pending.name,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMembershipStatus(String membershipId, MembershipStatus status) async {
    await _firestore.collection('memberships').doc(membershipId).update({
      'status': status.name,
    });
  }

  Future<void> leaveCommunity(String membershipId) async {
    await _firestore.collection('memberships').doc(membershipId).delete();
  }
}

// Providers for the UI
final userMembershipsProvider = StreamProvider.family<List<Membership>, String>((ref, userId) {
  return ref.watch(communityRepositoryProvider).watchUserMemberships(userId);
});

final allCommunitiesProvider = StreamProvider<List<Community>>((ref) {
  return ref.watch(communityRepositoryProvider).watchAllCommunities();
});
