import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../auth/application/auth_service.dart';
import '../../communities/data/community_repository.dart';
import '../../library/data/transaction_repository.dart';
import '../../library/domain/book_transaction.dart';

/// Provider to check if any managed community has pending membership requests.
final hasPendingMembershipsProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(false);

  final allCommunitiesAsync = ref.watch(allCommunitiesProvider);
  
  return allCommunitiesAsync.when(
    data: (communities) {
      final managedIds = communities
          .where((c) => c.adminId == user.uid)
          .map((c) => c.id)
          .toList();
      
      if (managedIds.isEmpty) return Stream.value(false);

      // Create a composite stream that checks all managed communities
      // For simplicity, we watch for any membership status update in these communities
      // Or we can just sum up the individuals
      return ref.watch(communityRepositoryProvider)._watchAnyPendingIn(managedIds);
    },
    loading: () => Stream.value(false),
    error: (_, __) => Stream.value(false),
  );
});

/// Extension on CommunityRepository to help with bulk pending checks
extension BadgeExtensions on CommunityRepository {
  Stream<bool> _watchAnyPendingIn(List<String> communityIds) {
    if (communityIds.isEmpty) return Stream.value(false);
    return FirebaseFirestore.instance
        .collection('memberships')
        .where('communityId', whereIn: communityIds)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }
}

/// Provider to check if there are any active transactions (incoming or outgoing).
final hasIncomingRequestsProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(false);

  final repo = ref.watch(transactionRepositoryProvider);
  
  final activeStatuses = [
    TransactionStatus.requested,
    TransactionStatus.approved,
    TransactionStatus.pickedUp,
    TransactionStatus.overdue,
  ];

  return CombineLatestStream.combine2(
    repo.watchIncomingRequests(user.uid),
    repo.watchOutgoingRequests(user.uid),
    (incoming, outgoing) {
      final hasActiveIncoming = incoming.any((t) => activeStatuses.contains(t.status));
      final hasActiveOutgoing = outgoing.any((t) => activeStatuses.contains(t.status));
      return hasActiveIncoming || hasActiveOutgoing;
    },
  );
});
