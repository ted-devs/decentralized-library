import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/community.dart';
import '../domain/membership.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';


final communityRepositoryProvider = Provider((ref) => CommunityRepository(FirebaseFirestore.instance));

class CommunityRepository {
  final FirebaseFirestore _firestore;
  CommunityRepository(this._firestore);

  Future<String> createCommunity(Community community) async {
    final docRef = await _firestore.collection('communities').add(community.toMap());
    
    // Auto-approve admin as member using deterministic ID
    final membershipId = '${community.adminId}_${docRef.id}';
    await _firestore.collection('memberships').doc(membershipId).set({
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
    final membershipId = '${userId}_${community.id}';
    await _firestore.collection('memberships').doc(membershipId).set({
      'communityId': community.id,
      'userId': userId,
      'status': MembershipStatus.pending.name,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateMembershipStatus(String membershipId, MembershipStatus status) async {
    await _firestore.collection('memberships').doc(membershipId).update({
      'status': status.name,
    });
  }

  Future<void> leaveCommunity(String membershipId) async {
    await _firestore.collection('memberships').doc(membershipId).delete();
  }

  Future<void> togglePinCommunity(String userId, String communityId, bool pin) async {
    final userRef = _firestore.collection('users').doc(userId);
    if (pin) {
      // Limit to 3 pins for clean UI
      final doc = await userRef.get();
      final currentPins = List<String>.from(doc.data()?['pinnedCommunities'] ?? []);
      if (currentPins.length >= 3) {
        throw Exception('You can only pin up to 3 communities.');
      }
      await userRef.update({
        'pinnedCommunities': FieldValue.arrayUnion([communityId]),
      });
    } else {
      await userRef.update({
        'pinnedCommunities': FieldValue.arrayRemove([communityId]),
      });
    }
  }
}

// Providers for the UI
final userMembershipsProvider = StreamProvider.family<List<Membership>, String>((ref, userId) {
  return ref.watch(communityRepositoryProvider).watchUserMemberships(userId);
});

final allCommunitiesProvider = StreamProvider<List<Community>>((ref) {
  return ref.watch(communityRepositoryProvider).watchAllCommunities();
});

// Helper providers to turn streams into AsyncValues for the UI
final communityMembersProvider = StreamProvider.family<List<Membership>, String>((ref, communityId) {
  return ref.watch(communityRepositoryProvider).watchCommunityMembers(communityId);
});

final communityPendingRequestsProvider = StreamProvider.family<List<Membership>, String>((ref, communityId) {
  return ref.watch(communityRepositoryProvider).watchPendingRequests(communityId);
});

final communityLibraryProvider = StreamProvider.family<List<Book>, String>((ref, communityId) {
  final user = ref.watch(authStateProvider).value;
  final membersAsync = ref.watch(communityMembersProvider(communityId));
  
  return membersAsync.when(
    data: (members) {
      final otherMemberIds = members
          .where((m) => m.userId != user?.uid)
          .map((m) => m.userId)
          .toList();
      return ref.watch(bookshelfRepositoryProvider).watchCommunityLibrary(otherMemberIds);
    },
    loading: () => const Stream.empty(),
    error: (e, st) => Stream.error(e),
  );
});
