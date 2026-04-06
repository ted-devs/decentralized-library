import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/communities/domain/community.dart';
import 'package:decentralized_library/src/features/communities/domain/membership.dart';
import 'community_detail_screen.dart';

class CommunityInfoScreen extends ConsumerWidget {
  final Community community;
  const CommunityInfoScreen({super.key, required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final isAdmin = community.adminId == user?.uid;
    final membershipsAsync = user != null 
        ? ref.watch(userMembershipsProvider(user.uid)) 
        : const AsyncValue<List<Membership>>.loading();
    final membersAsync = ref.watch(communityMembersProvider(community.id));
    final adminProfileAsync = ref.watch(userProvider(community.adminId));

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Community Info')),
      body: membershipsAsync.when(
        data: (memberships) {
          final membership = memberships.where((m) => m.communityId == community.id).firstOrNull;
          final status = membership?.status;
          final isApproved = status == MembershipStatus.approved || isAdmin;
          final isPending = status == MembershipStatus.pending;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.group_rounded, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  community.name,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
                        data: (m) => '${m.length} Member${m.length == 1 ? '' : 's'}',
                        loading: () => '...',
                        error: (_, __) => '?',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Description
                Text('About', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(community.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
                
                // Admin Info
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.shield_outlined)),
                  title: const Text('Administrator'),
                  subtitle: adminProfileAsync.when(
                    data: (profile) => Text(profile?.displayName ?? 'Community Admin'),
                    loading: () => const Text('Loading...'),
                    error: (_, __) => const Text('Error loading admin'),
                  ),
                ),
                
                const SizedBox(height: 48),

                // Primary Action Button
                if (isPending)
                  ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.hourglass_empty_rounded),
                    label: const Text('Membership Pending'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else if (!isApproved)
                  ElevatedButton.icon(
                    onPressed: () => _joinCommunity(context, ref),
                    icon: const Icon(Icons.group_add_rounded),
                    label: const Text('Join Community'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _joinCommunity(BuildContext context, WidgetRef ref) async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      
      await ref.read(communityRepositoryProvider).requestToJoin(user.uid, community);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Join request sent for ${community.name}!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to join: $e')));
      }
    }
  }
}
