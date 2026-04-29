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
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
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
                MaterialPageRoute(
                  builder: (_) => CommunityInfoScreen(community: community),
                ),
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
              final membership = memberships
                  .where((m) => m.communityId == community.id)
                  .firstOrNull;
              final isApproved =
                  isAdmin || membership?.status == MembershipStatus.approved;

              if (!isApproved) {
                return const Center(
                  child: Text(
                    'You must be an approved member to view this community.',
                  ),
                );
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
                                isLabelVisible:
                                    ref
                                        .watch(
                                          communityPendingRequestsProvider(
                                            community.id,
                                          ),
                                        )
                                        .value
                                        ?.isNotEmpty ??
                                    false,
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
    final libraryAsync = ref.watch(
      filteredCommunityLibraryProvider(community.id),
    );
    final searchQuery = ref.watch(communityLibrarySearchQueryProvider);
    final sortOption = ref.watch(communityLibrarySortProvider);
    final statusFilter = ref.watch(communityLibraryStatusProvider);

    return Column(
      children: [
        // Search and Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search title or author...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => ref
                                .read(
                                  communityLibrarySearchQueryProvider.notifier,
                                )
                                .set(''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) => ref
                      .read(communityLibrarySearchQueryProvider.notifier)
                      .set(value),
                ),
              ),
              const SizedBox(width: 8),
              _FilterButton(communityId: community.id),
            ],
          ),
        ),
        const Divider(),

        // Book List
        Expanded(
          child: libraryAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    searchQuery.isNotEmpty ||
                            statusFilter != CommunityLibraryStatus.all
                        ? 'No books match your filters.'
                        : 'No books shared in this community yet.',
                  ),
                );
              }

              final viewMode = ref.watch(communityLibraryViewModeProvider);
              final gridSize = ref.watch(communityLibraryGridSizeProvider);

              if (viewMode == BookshelfViewMode.grid) {
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 100),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridSize == BookshelfGridSize.small ? 4 : 3,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _CommunityBookGridItem(item: items[index]);
                  },
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _CommunityLibraryTile(item: items[index]);
                },
              );
            },
            loading: () => const _CommunityLibrarySkeleton(),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _CommunityLibraryTile extends StatelessWidget {
  final CommunityLibraryItem item;
  const _CommunityLibraryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final book = item.book;
    final isUnavailable = item.isUnavailable;

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
                child: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BookDetailsScreen(book: book)),
        ),
      ),
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
        final regularMembers = members
            .where((m) => m.userId != community.adminId)
            .toList();

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
              onTap: userAsync.value != null
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(
                            user: userAsync.value!,
                            membership: member,
                          ),
                        ),
                      );
                    }
                  : null,
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
    final requestsAsync = ref.watch(
      communityPendingRequestsProvider(community.id),
    );

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty)
          return const Center(child: Text('No pending requests.'));

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
              onTap: userAsync.value != null
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(
                            user: userAsync.value!,
                            membership: request,
                          ),
                        ),
                      );
                    }
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => ref
                        .read(communityRepositoryProvider)
                        .updateMembershipStatus(
                          request.id,
                          MembershipStatus.approved,
                          communityName: community.name,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => ref
                        .read(communityRepositoryProvider)
                        .updateMembershipStatus(
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

class _FilterButton extends ConsumerWidget {
  final String communityId;
  const _FilterButton({required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(communityLibraryStatusProvider);
    final sortOption = ref.watch(communityLibrarySortProvider);
    final viewMode = ref.watch(communityLibraryViewModeProvider);

    final bool hasActiveFilters = statusFilter != CommunityLibraryStatus.all;

    return IconButton.filledTonal(
      icon: Badge(
        isLabelVisible: hasActiveFilters,
        child: const Icon(Icons.tune_rounded),
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (context) => _FilterSheet(communityId: communityId),
        );
      },
      tooltip: 'Filters',
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  final String communityId;
  const _FilterSheet({required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(communityLibraryStatusProvider);
    final sortOption = ref.watch(communityLibrarySortProvider);
    final viewMode = ref.watch(communityLibraryViewModeProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Filters & Sorting', style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),

          Text('Status', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: CommunityLibraryStatus.values.map((status) {
              return ChoiceChip(
                label: Text(
                  status.name[0].toUpperCase() + status.name.substring(1),
                ),
                selected: statusFilter == status,
                onSelected: (selected) {
                  if (selected)
                    ref
                        .read(communityLibraryStatusProvider.notifier)
                        .set(status);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          Text('Sort By', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          DropdownButtonFormField<CommunityLibrarySort>(
            value: sortOption,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            items: const [
              DropdownMenuItem(
                value: CommunityLibrarySort.recentlyAdded,
                child: Text('Recently Added'),
              ),
              DropdownMenuItem(
                value: CommunityLibrarySort.titleAZ,
                child: Text('Title A-Z'),
              ),
              DropdownMenuItem(
                value: CommunityLibrarySort.titleZA,
                child: Text('Title Z-A'),
              ),
            ],
            onChanged: (val) {
              if (val != null)
                ref.read(communityLibrarySortProvider.notifier).set(val);
            },
          ),

          const SizedBox(height: 24),
          Text('View Mode', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          SegmentedButton<BookshelfViewMode>(
            segments: const [
              ButtonSegment(
                value: BookshelfViewMode.grid,
                label: Text('Grid'),
                icon: Icon(Icons.grid_view_rounded),
              ),
              ButtonSegment(
                value: BookshelfViewMode.list,
                label: Text('List'),
                icon: Icon(Icons.view_list_rounded),
              ),
            ],
            selected: {viewMode},
            onSelectionChanged: (newSelection) {
              ref
                  .read(communityLibraryViewModeProvider.notifier)
                  .set(newSelection.first);
            },
          ),

          if (viewMode == BookshelfViewMode.grid) ...[
            const SizedBox(height: 24),
            Text('Grid Size', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            SegmentedButton<BookshelfGridSize>(
              segments: const [
                ButtonSegment(
                  value: BookshelfGridSize.small,
                  label: Text('Small'),
                  icon: Icon(Icons.grid_on_rounded),
                ),
                ButtonSegment(
                  value: BookshelfGridSize.medium,
                  label: Text('Medium'),
                  icon: Icon(Icons.grid_view_rounded),
                ),
              ],
              selected: {ref.watch(communityLibraryGridSizeProvider)},
              onSelectionChanged: (newSelection) {
                ref
                    .read(communityLibraryGridSizeProvider.notifier)
                    .set(newSelection.first);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CommunityBookGridItem extends ConsumerWidget {
  final CommunityLibraryItem item;

  const _CommunityBookGridItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = item.book;
    final isUnavailable = item.isUnavailable;
    final theme = Theme.of(context);
    final gridSize = ref.watch(communityLibraryGridSizeProvider);
    final isSmall = gridSize == BookshelfGridSize.small;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BookDetailsScreen(book: book)),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Opacity(
                opacity: isUnavailable ? 0.4 : 1.0,
                child: BookCover(
                  url: book.coverUrl,
                  width: double.infinity,
                  height: double.infinity,
                  useCache: true,
                ),
              ),
            ),
          ),
          // Gradient and Text Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 32, 8, 12),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(180),
                    Colors.black.withAlpha(220),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmall ? 11 : 12,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(100),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: isSmall ? 9 : 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Status Badges
          if (isUnavailable)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.remove_circle,
                  color: Colors.grey,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
