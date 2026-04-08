import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/communities/domain/community.dart';
import 'package:decentralized_library/src/features/communities/domain/membership.dart';
import 'community_info_screen.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/book_details_screen.dart';
import 'package:decentralized_library/src/features/bookshelf/presentation/widgets/book_cover.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';
import 'package:decentralized_library/src/features/library/application/active_transaction_service.dart';
import 'user_profile_screen.dart';
import 'package:shimmer/shimmer.dart';

// (Providers moved to community_repository.dart)

class CommunityDetailScreen extends ConsumerWidget {
  final Community community;
  const CommunityDetailScreen({super.key, required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The Scaffold shell is rendered immediately to ensure smooth navigation transitions.
    // It does not watch ANY changing data top-level to prevent redundant build calls during push/pop.
    return Scaffold(
      appBar: AppBar(
        title: Text(community.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CommunityInfoScreen(community: community)),
              );
            },
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final user = ref.watch(authStateProvider).value;
          if (user == null) return const Center(child: Text('Please log in.'));

          // Use whenData to transform the whole membership list into just the one we care about.
          final membershipsAsync = ref.watch(userMembershipsProvider(user.uid));
          final isAdmin = community.adminId == user.uid;

          return membershipsAsync.when(
            data: (memberships) {
              final membership = memberships.where((m) => m.communityId == community.id).firstOrNull;
              final isApproved = isAdmin || membership?.status == MembershipStatus.approved;

              if (!isApproved) {
                return const Center(child: Text('You must be an approved member to view this community.'));
              }

              if (isAdmin) {
                return DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      Material(
                        color: Theme.of(context).cardColor,
                        elevation: 1, // Add subtle shadow for premium feel
                        child: TabBar(
                          tabs: [
                            const Tab(text: 'Library'),
                            const Tab(text: 'Members'),
                            Tab(
                              child: Badge(
                                isLabelVisible: ref.watch(communityPendingRequestsProvider(community.id)).value?.isNotEmpty ?? false,
                                child: const Text('Requests'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _CommunityLibraryView(community: community),
                            _CommunityMembersView(community: community),
                            _CommunityRequestsView(community: community),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Standard member view
              return _CommunityLibraryView(community: community);
            },
            loading: () => const _CommunityLibrarySkeleton(),
            error: (e, st) => Center(child: Text('Error: $e')),
          );
        },
      ),
    );
  }
}

class _CommunityLibraryView extends ConsumerWidget {
  final Community community;
  const _CommunityLibraryView({required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(communityLibraryProvider(community.id));

    return libraryAsync.when(
      data: (books) {
        if (books.isEmpty) return const Center(child: Text('No books shared in this community yet.'));
        
        return ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, index) {
            return _CommunityLibraryTile(book: books[index]);
          },
        );
      },
      loading: () => const _CommunityLibrarySkeleton(),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _CommunityLibraryTile extends ConsumerWidget {
  final Book book;
  const _CommunityLibraryTile({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmedTxAsync = ref.watch(confirmedTransactionForBookProvider(book.id));

    return confirmedTxAsync.when(
      data: (tx) {
        final isUnavailable = tx != null;
        
        return Opacity(
          opacity: isUnavailable ? 0.6 : 1.0,
          child: ListTile(
            leading: BookCover(
              url: book.coverUrl,
              width: 40,
              height: 60,
              useCache: true,
            ),
            title: Text(
              book.title,
              style: TextStyle(
                fontWeight: isUnavailable ? FontWeight.normal : FontWeight.bold,
                color: isUnavailable ? Colors.grey : null,
              ),
            ),
            subtitle: Text(book.author),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUnavailable)
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BookDetailsScreen(book: book)),
            ),
          ),
        );
      },
      loading: () => const ListTile(
        leading: SizedBox(width: 40, height: 60),
        title: Text('...'),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CommunityLibrarySkeleton extends StatelessWidget {
  const _CommunityLibrarySkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (context, index) => ListTile(
        leading: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(width: 40, height: 60, color: Colors.white),
        ),
        title: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(width: 150, height: 12, color: Colors.white),
        ),
        subtitle: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(width: 100, height: 10, color: Colors.white),
        ),
      ),
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
        final regularMembers = members.where((m) => m.userId != community.adminId).toList();
        
        if (regularMembers.isEmpty) {
          return const Center(child: Text('No members yet.'));
        }

        return ListView.builder(
          itemCount: regularMembers.length,
          itemBuilder: (context, index) {
            final member = regularMembers[index];
            final userAsync = ref.watch(userProvider(member.userId));
            
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: userAsync.when(
                data: (user) => Text(user?.displayName ?? 'Unknown User'),
                loading: () => const Text('Loading...'),
                error: (_, __) => const Text('Error loading user'),
              ),
              onTap: userAsync.value != null ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      user: userAsync.value!,
                      membership: member,
                    ),
                  ),
                );
              } : null,
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
            final userAsync = ref.watch(userProvider(request.userId));

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: userAsync.when(
                data: (user) => Text(user?.displayName ?? 'Unknown User'),
                loading: () => const Text('Loading...'),
                error: (_, __) => const Text('Error loading user'),
              ),
              onTap: userAsync.value != null ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      user: userAsync.value!,
                      membership: request,
                    ),
                  ),
                );
              } : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => ref.read(communityRepositoryProvider).updateMembershipStatus(
                      request.id, 
                      MembershipStatus.approved,
                      communityName: community.name,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => ref.read(communityRepositoryProvider).updateMembershipStatus(
                      request.id, 
                      MembershipStatus.rejected,
                      communityName: community.name,
                    ),
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
