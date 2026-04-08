import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/communities/domain/community.dart';
import 'package:decentralized_library/src/features/communities/domain/membership.dart';
import 'community_detail_screen.dart';

class CommunityInfoScreen extends ConsumerStatefulWidget {
  final Community community;
  const CommunityInfoScreen({super.key, required this.community});

  @override
  ConsumerState<CommunityInfoScreen> createState() =>
      _CommunityInfoScreenState();
}

class _CommunityInfoScreenState extends ConsumerState<CommunityInfoScreen> {
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isAdmin = widget.community.adminId == user?.uid;
    final membershipsAsync = user != null
        ? ref.watch(userMembershipsProvider(user.uid))
        : const AsyncValue<List<Membership>>.loading();
    final membersAsync = ref.watch(
      communityMembersProvider(widget.community.id),
    );
    final adminProfileAsync = ref.watch(userProvider(widget.community.adminId));

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Info'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final appUser = ref.watch(appUserProvider).value;
              if (appUser == null) return const SizedBox.shrink();

              // Only show pin button if they are an approved member or admin
              final memberships = ref.watch(userMembershipsProvider(appUser.uid)).value ?? [];
              final isApproved = appUser.uid == widget.community.adminId || 
                                memberships.any((m) => m.communityId == widget.community.id && m.status == MembershipStatus.approved);
              
              if (!isApproved) return const SizedBox.shrink();

              final isPinned = appUser.pinnedCommunities.contains(
                widget.community.id,
              );
              return IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: isPinned ? Colors.blue : null,
                ),
                onPressed: () async {
                  try {
                    await ref
                        .read(communityRepositoryProvider)
                        .togglePinCommunity(
                          appUser.uid,
                          widget.community.id,
                          !isPinned,
                        );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceAll('Exception: ', ''),
                          ),
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        ],
      ),
      body: membershipsAsync.when(
        data: (memberships) {
          final communityMemberships = memberships
              .where((m) => m.communityId == widget.community.id)
              .toList();

          final isApproved =
              isAdmin ||
              communityMemberships.any(
                (m) => m.status == MembershipStatus.approved,
              );
          final isPending = communityMemberships.any(
            (m) => m.status == MembershipStatus.pending,
          );
          final membership = communityMemberships.firstOrNull;

          final theme = Theme.of(context);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    radius: 40,
                    child: Icon(
                      Icons.group_rounded,
                      size: 40,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.community.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatChip(
                      context,
                      Icons.people_alt_rounded,
                      membersAsync.when(
                        data: (m) =>
                            '${m.length} Member${m.length == 1 ? '' : 's'}',
                        loading: () => '...',
                        error: (_, __) => '?',
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      context,
                      Icons.menu_book_rounded,
                      ref
                          .watch(communityLibraryProvider(widget.community.id))
                          .when(
                            data: (books) =>
                                '${books.length} Book${books.length == 1 ? '' : 's'}',
                            loading: () => '...',
                            error: (_, __) => '?',
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Description
                Text(
                  'About',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.community.description,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Admin Info
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.shield_outlined),
                  ),
                  title: const Text('Administrator'),
                  subtitle: adminProfileAsync.when(
                    data: (profile) =>
                        Text(profile?.displayName ?? 'Community Admin'),
                    loading: () => const Text('Loading...'),
                    error: (_, __) => const Text('Error loading admin'),
                  ),
                ),

                const SizedBox(height: 48),

                // Primary Action Button
                if (isPending || _isRequesting)
                  ElevatedButton.icon(
                    onPressed: null,
                    icon: _isRequesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.hourglass_empty_rounded),
                    label: Text(
                      _isRequesting ? 'Requesting...' : 'Membership Pending',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else if (!isApproved)
                  ElevatedButton.icon(
                    onPressed: () => _joinCommunity(context),
                    icon: const Icon(Icons.group_add_rounded),
                    label: const Text('Join Community'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (isApproved && !isAdmin)
                  OutlinedButton.icon(
                    onPressed: () => _showLeaveDialog(context, membership!.id),
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    label: const Text(
                      'Leave Community',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                if (isAdmin)
                  const SizedBox(height: 16),
                if (isAdmin)
                  OutlinedButton.icon(
                    onPressed: () => _showDeleteCommunityDialog(context),
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      'Delete Community',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinCommunity(BuildContext context) async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      setState(() => _isRequesting = true);
      await ref
          .read(communityRepositoryProvider)
          .requestToJoin(user.uid, widget.community);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Join request sent for ${widget.community.name}!'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to join: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _showLeaveDialog(
    BuildContext context,
    String membershipId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Community?'),
        content: const Text(
          'Are you sure you want to leave this community? You will lose access to the shared library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Left community.')));
      }
    }
  }

  Future<void> _showDeleteCommunityDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Community?'),
        content: const Text(
          'This will permanently delete this community and remove all membership records. This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(communityRepositoryProvider).deleteCommunity(widget.community.id);
        if (context.mounted) {
          // Navigate back twice to get out of Info and Detail screens
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Community deleted.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete community: $e')),
          );
        }
      }
    }
  }
}
