import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../domain/community.dart';
import '../domain/membership.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
import 'package:decentralized_library/src/features/notifications/domain/app_notification.dart';
import 'package:decentralized_library/src/features/library/application/active_transaction_service.dart';


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

  Future<void> updateCommunityDescription(String communityId, String newDescription) async {
    await _firestore.collection('communities').doc(communityId).update({
      'description': newDescription,
    });
  }

  Future<void> generateInviteCode(String communityId) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random();
    final code = String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

    await _firestore.collection('communities').doc(communityId).update({
      'inviteCode': code,
      'inviteExpiry':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    });
  }

  Future<String> joinWithInviteCode(String userId, String inviteCode) async {
    final query = await _firestore
        .collection('communities')
        .where('inviteCode', isEqualTo: inviteCode.trim().toUpperCase())
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid invite code.');
    }

    final doc = query.docs.first;
    final community = Community.fromMap(doc.data(), doc.id);

    if (community.inviteExpiry == null ||
        community.inviteExpiry!.isBefore(DateTime.now())) {
      throw Exception('This invite code has expired.');
    }

    final membershipId = '${userId}_${community.id}';
    await _firestore.collection('memberships').doc(membershipId).set({
      'communityId': community.id,
      'userId': userId,
      'status': MembershipStatus.approved.name,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return community.name;
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
      // Membership Phase: Verify user is an approved member
      final membershipId = '${userId}_${communityId}';
      final membershipDoc = await _firestore.collection('memberships').doc(membershipId).get();
      
      final isApproved = membershipDoc.exists && 
                         membershipDoc.data()?['status'] == MembershipStatus.approved.name;
      
      if (!isApproved) {
        throw Exception('You can only pin communities that you are a member of.');
      }

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

class CommunityLibraryItem {
  final Book book;
  final bool isUnavailable;

  CommunityLibraryItem({
    required this.book,
    this.isUnavailable = false,
  });
}

enum CommunityLibrarySort { recentlyAdded, titleAZ, titleZA }
enum CommunityLibraryStatus { all, available, unavailable }

class CommunityLibrarySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}
final communityLibrarySearchQueryProvider = NotifierProvider<CommunityLibrarySearchQueryNotifier, String>(() => CommunityLibrarySearchQueryNotifier());

class CommunityLibrarySortNotifier extends Notifier<CommunityLibrarySort> {
  @override
  CommunityLibrarySort build() => CommunityLibrarySort.recentlyAdded;
  void set(CommunityLibrarySort value) => state = value;
}
final communityLibrarySortProvider = NotifierProvider<CommunityLibrarySortNotifier, CommunityLibrarySort>(() => CommunityLibrarySortNotifier());

class CommunityLibraryStatusNotifier extends Notifier<CommunityLibraryStatus> {
  @override
  CommunityLibraryStatus build() => CommunityLibraryStatus.all;
  void set(CommunityLibraryStatus value) => state = value;
}
final communityLibraryStatusProvider = NotifierProvider<CommunityLibraryStatusNotifier, CommunityLibraryStatus>(() => CommunityLibraryStatusNotifier());

class CommunityLibraryViewModeNotifier extends Notifier<BookshelfViewMode> {
  @override
  BookshelfViewMode build() => BookshelfViewMode.grid;
  void toggle() => state = state == BookshelfViewMode.grid ? BookshelfViewMode.list : BookshelfViewMode.grid;
  void set(BookshelfViewMode mode) => state = mode;
}
final communityLibraryViewModeProvider = NotifierProvider<CommunityLibraryViewModeNotifier, BookshelfViewMode>(() => CommunityLibraryViewModeNotifier());

class CommunityLibraryGridSizeNotifier extends Notifier<BookshelfGridSize> {
  @override
  BookshelfGridSize build() => BookshelfGridSize.medium;
  void set(BookshelfGridSize size) => state = size;
}
final communityLibraryGridSizeProvider = NotifierProvider<CommunityLibraryGridSizeNotifier, BookshelfGridSize>(() => CommunityLibraryGridSizeNotifier());

final filteredCommunityLibraryProvider = Provider.family<AsyncValue<List<CommunityLibraryItem>>, String>((ref, communityId) {
  final libraryAsync = ref.watch(communityLibraryProvider(communityId));
  final searchQuery = ref.watch(communityLibrarySearchQueryProvider).toLowerCase();
  final sortOption = ref.watch(communityLibrarySortProvider);
  final statusFilter = ref.watch(communityLibraryStatusProvider);

  return libraryAsync.whenData((books) {
    List<CommunityLibraryItem> items = [];
    
    for (var book in books) {
      final txAsync = ref.watch(confirmedTransactionForBookProvider(book.id));
      final isUnavailable = txAsync.value != null;
      items.add(CommunityLibraryItem(book: book, isUnavailable: isUnavailable));
    }

    var filtered = items.where((item) {
      if (statusFilter == CommunityLibraryStatus.available && item.isUnavailable) return false;
      if (statusFilter == CommunityLibraryStatus.unavailable && !item.isUnavailable) return false;

      if (searchQuery.isNotEmpty) {
        final matchesTitle = item.book.title.toLowerCase().contains(searchQuery);
        final matchesAuthor = item.book.author.toLowerCase().contains(searchQuery);
        if (!matchesTitle && !matchesAuthor) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (sortOption) {
        case CommunityLibrarySort.recentlyAdded: return 0;
        case CommunityLibrarySort.titleAZ: return a.book.title.compareTo(b.book.title);
        case CommunityLibrarySort.titleZA: return b.book.title.compareTo(a.book.title);
      }
    });

    return filtered;
  });
});

