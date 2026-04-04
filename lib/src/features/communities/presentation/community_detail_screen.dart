import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/communities/domain/community.dart';
import 'package:decentralized_library/src/features/communities/domain/membership.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/book_details_screen.dart';

// Helper providers to turn streams into AsyncValues for the UI
final communityMembersProvider = StreamProvider.family<List<Membership>, String>((ref, communityId) {
  return ref.watch(communityRepositoryProvider).watchCommunityMembers(communityId);
});

final communityPendingRequestsProvider = StreamProvider.family<List<Membership>, String>((ref, communityId) {
  return ref.watch(communityRepositoryProvider).watchPendingRequests(communityId);
});

final memberBooksProvider = StreamProvider.family<List, String>((ref, userId) {
  return ref.watch(bookshelfRepositoryProvider).watchOwnedBooks(userId);
});

class CommunityDetailScreen extends ConsumerWidget {
  final Community community;
  const CommunityDetailScreen({super.key, required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final isAdmin = community.adminId == user?.uid;
    
    // Check membership status
    final membershipsAsync = user != null ? ref.watch(userMembershipsProvider(user.uid)) : const AsyncValue<List<Membership>>.loading();
    
    return membershipsAsync.when(
      data: (memberships) {
        final membership = memberships.where((m) => m.communityId == community.id).firstOrNull;
        final isApproved = membership?.status == MembershipStatus.approved;

        if (!isAdmin && !isApproved) {
          return Scaffold(
            appBar: AppBar(title: Text(community.name)),
            body: const Center(child: Text('You must be an approved member to view this community.')),
          );
        }

        if (isAdmin) {
          return DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBar(
                title: Text(community.name),
                actions: [
                  if (!isAdmin && membership != null)
                    IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.red),
                      tooltip: 'Leave Community',
                      onPressed: () => _showLeaveDialog(context, ref, membership.id),
                    ),
                ],
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Library'),
                    Tab(text: 'Members'),
                    Tab(text: 'Requests'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _CommunityLibraryView(community: community),
                  _CommunityMembersView(community: community),
                  _CommunityRequestsView(community: community),
                ],
              ),
            ),
          );
        }

        // Standard member view - No tabs, just library
        return Scaffold(
          appBar: AppBar(
            title: Text(community.name),
            actions: [
              if (membership != null)
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                  tooltip: 'Leave Community',
                  onPressed: () => _showLeaveDialog(context, ref, membership.id),
                ),
            ],
          ),
          body: _CommunityLibraryView(community: community),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
  Future<void> _showLeaveDialog(BuildContext context, WidgetRef ref, String membershipId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Community?'),
        content: const Text('Are you sure you want to leave this community? You will lose access to the shared library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(communityRepositoryProvider).leaveCommunity(membershipId);
      if (context.mounted) {
        Navigator.pop(context); // Go back to hub
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left community.')));
      }
    }
  }
}

class _CommunityLibraryView extends ConsumerWidget {
  final Community community;
  const _CommunityLibraryView({required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(communityMembersProvider(community.id));

    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) return const Center(child: Text('No members yet.'));
        
        return ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final memberId = members[index].userId;
            return _MemberBooksSection(memberId: memberId);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _MemberBooksSection extends ConsumerWidget {
  final String memberId;
  const _MemberBooksSection({required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(memberBooksProvider(memberId));

    return booksAsync.when(
      data: (books) {
        final shareableBooks = books.where((b) => b.isShareable).toList();
        if (shareableBooks.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Member Collection (${memberId.substring(0, 5)}...)', 
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
            ),
            ...shareableBooks.map((book) => ListTile(
              leading: book.coverUrl != null 
                  ? Image.network(book.coverUrl!, width: 40, height: 60, fit: BoxFit.cover) 
                  : const Icon(Icons.book),
              title: Text(book.title),
              subtitle: Text(book.author),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BookDetailsScreen(book: book)),
              ),
            )),
            const Divider(),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

class _CommunityMembersView extends ConsumerWidget {
  final Community community;
  const _CommunityMembersView({required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(communityMembersProvider(community.id));

    return membersAsync.when(
      data: (members) {
        return ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('User ${member.userId.substring(0, 8)}'),
              subtitle: Text(member.userId == community.adminId ? 'Administrator' : 'Member'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _CommunityRequestsView extends ConsumerWidget {
  final Community community;
  const _CommunityRequestsView({required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(communityPendingRequestsProvider(community.id));

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) return const Center(child: Text('No pending requests.'));

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return ListTile(
              title: Text('User ${request.userId.substring(0, 8)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => ref.read(communityRepositoryProvider).updateMembershipStatus(request.id, MembershipStatus.approved),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => ref.read(communityRepositoryProvider).updateMembershipStatus(request.id, MembershipStatus.rejected),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
