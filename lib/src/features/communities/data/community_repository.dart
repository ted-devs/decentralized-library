import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/community.dart';
import '../domain/membership.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
import 'package:decentralized_library/src/features/notifications/domain/app_notification.dart';


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

    // Send notification to admin
    final appUser = await _firestore.collection('users').doc(userId).get();
    final displayName = appUser.data()?['displayName'] ?? 'A user';
    
    await _firestore.collection('notifications').add({
      'recipientId': community.adminId,
      'senderId': userId,
      'type': NotificationType.joinRequest.name,
      'title': 'New Join Request',
      'body': '$displayName wants to join ${community.name}',
      'relatedId': community.id,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> updateMembershipStatus(String membershipId, MembershipStatus status, {required String communityName}) async {
    await _firestore.collection('memberships').doc(membershipId).update({
      'status': status.name,
    });

    if (status == MembershipStatus.approved) {
      final membershipDoc = await _firestore.collection('memberships').doc(membershipId).get();
      final userId = membershipDoc.data()?['userId'];
      final communityId = membershipDoc.data()?['communityId'];

      if (userId != null) {
        await _firestore.collection('notifications').add({
          'recipientId': userId,
          'type': NotificationType.membershipApproved.name,
          'title': 'Membership Approved!',
          'body': 'You are now a member of $communityName',
          'relatedId': communityId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    }
  }

  Future<void> leaveCommunity(String membershipId) async {
    await _firestore.collection('memberships').doc(membershipId).delete();
  }

  Future<void> deleteCommunity(String communityId) async {
    final batch = _firestore.batch();
    
    // 1. Delete the community document
    batch.delete(_firestore.collection('communities').doc(communityId));
    
    // 2. Delete all memberships for this community
    final memberships = await _firestore
        .collection('memberships')
        .where('communityId', isEqualTo: communityId)
        .get();
    
    for (var doc in memberships.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  Future<void> togglePinCommunity(String userId, String communityId, bool pin) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    final List<String> currentPins = List<String>.from(userDoc.data()?['pinnedCommunities'] ?? []);

    // Validation Phase: Check if all currently pinned communities still exist
    final existenceResults = await Future.wait(
      currentPins.map((id) => _firestore.collection('communities').doc(id).get().then((doc) => doc.exists))
    );

    final List<String> cleanedPins = [];
    for (int i = 0; i < currentPins.length; i++) {
      if (existenceResults[i]) {
        cleanedPins.add(currentPins[i]);
      }
    }

    if (pin) {
      if (!cleanedPins.contains(communityId)) {
        if (cleanedPins.length >= 3) {
          // If after cleaning we are still at limit, then block
          throw Exception('You can only pin up to 3 communities.');
        }
        cleanedPins.add(communityId);
      }
    } else {
      cleanedPins.remove(communityId);
    }

    // Update with the cleaned (and potentially updated) list
    await userRef.update({
      'pinnedCommunities': cleanedPins,
    });
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
