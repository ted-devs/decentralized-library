import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    final allCommunitiesAsync = ref.watch(allCommunitiesProvider);
    final community = allCommunitiesAsync.value?.firstWhere(
      (c) => c.id == widget.community.id,
      orElse: () => widget.community,
    ) ?? widget.community;

    final user = ref.watch(authStateProvider).value;
    final isAdmin = community.adminId == user?.uid;
    final membershipsAsync = user != null
        ? ref.watch(userMembershipsProvider(user.uid))
        : const AsyncValue<List<Membership>>.loading();
    final membersAsync = ref.watch(
      communityMembersProvider(community.id),
    );
    final adminProfileAsync = ref.watch(userProvider(community.adminId));

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
              final isApproved = appUser.uid == community.adminId || 
                                memberships.any((m) => m.communityId == community.id && m.status == MembershipStatus.approved);
              
              if (!isApproved) return const SizedBox.shrink();

              final isPinned = appUser.pinnedCommunities.contains(
                community.id,
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
                          community.id,
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
              .where((m) => m.communityId == community.id)
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
                  community.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Stats Row
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
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
                    _buildStatChip(
                      context,
                      Icons.menu_book_rounded,
                      ref
                          .watch(communityLibraryProvider(community.id))
                          .when(
                            data: (books) =>
                                '${books.length} Book${books.length == 1 ? '' : 's'}',
                            loading: () => '...',
                            error: (_, __) => '?',
                          ),
                    ),
                    _buildStatChip(
                      context,
                      community.isPublic ? Icons.public : Icons.lock_outline,
                      community.isPublic ? 'Public' : 'Private',
                      color: community.isPublic
                          ? Colors.green.withAlpha(40)
                          : Colors.orange.withAlpha(40),
                      textColor: community.isPublic ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Description
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'About',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditDescriptionDialog(context, community),
                        tooltip: 'Edit Description',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  community.description,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Location & Details
                Text(
                  'Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text('${community.country}, ${community.city}'),
                  dense: true,
                ),
                if (community.organization != null && community.organization!.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.business_outlined),
                    title: Text(community.organization!),
                    dense: true,
                  ),
                const SizedBox(height: 24),

                // Invite System (Admin Only)
                if (isAdmin) ...[
                  Text(
                    'Invite System',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          if (community.inviteCode != null &&
                              community.inviteExpiry != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Active Code',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                    Text(community.inviteCode!,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 2)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(
                                            text: community.inviteCode!));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('Code copied!')),
                                        );
                                      },
                                      tooltip: 'Copy Code',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.refresh_rounded),
                                      onPressed: () => ref
                                          .read(communityRepositoryProvider)
                                          .generateInviteCode(community.id),
                                      tooltip: 'Refresh Code',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  'Expires: ${DateFormat('MMM d, yyyy').format(community.inviteExpiry!)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ] else
                            Column(
                              children: [
                                const Text(
                                    'No active invite code. Generate one to allow users to join instantly.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => ref
                                      .read(communityRepositoryProvider)
                                      .generateInviteCode(community.id),
                                  icon: const Icon(Icons.add_link_rounded),
                                  label: const Text('Generate Invite Code'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

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

  Widget _buildStatChip(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: textColor ?? theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor ?? theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 12,
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

  Future<void> _showEditDescriptionDialog(BuildContext context, Community community) async {
    final controller = TextEditingController(text: community.description);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Description'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Cannot be empty' : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setStateDialog(() => isSaving = true);
                    try {
                      await ref.read(communityRepositoryProvider).updateCommunityDescription(
                        community.id,
                        controller.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Description updated')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                        setStateDialog(() => isSaving = false);
                      }
                    }
                  },
                  child: isSaving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
