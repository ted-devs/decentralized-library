import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/communities/domain/community.dart';
import 'package:decentralized_library/src/features/communities/domain/membership.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';

class CommunitiesHubScreen extends ConsumerWidget {
  const CommunitiesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final allCommunitiesAsync = ref.watch(allCommunitiesProvider);
    final userMembershipsAsync = user != null 
        ? ref.watch(userMembershipsProvider(user.uid)) 
        : const AsyncValue<List<Membership>>.loading();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
              );
            },
          ),
        ],
      ),
      body: userMembershipsAsync.when(
        data: (memberships) {
          return allCommunitiesAsync.when(
            data: (allCommunities) {
              final membershipMap = {for (var m in memberships) m.communityId: m};
              
              final myCommunities = allCommunities.where((c) => membershipMap.containsKey(c.id)).toList();
              final otherCommunities = allCommunities.where((c) => !membershipMap.containsKey(c.id)).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (myCommunities.isNotEmpty) ...[
                    _buildSectionHeader('My Communities'),
                    const SizedBox(height: 8),
                    ...myCommunities.map((c) => _buildCommunityCard(context, ref, c, membershipMap[c.id])),
                    const SizedBox(height: 24),
                  ],
                  if (otherCommunities.isNotEmpty) ...[
                    _buildSectionHeader('Discover More'),
                    const SizedBox(height: 8),
                    ...otherCommunities.map((c) => _buildCommunityCard(context, ref, c, null)),
                  ],
                  if (allCommunities.isEmpty)
                    const Center(child: Text('No communities found. Create the first one!')),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCommunityCard(BuildContext context, WidgetRef ref, Community community, Membership? membership) {
    final status = membership?.status;
    final isApproved = status == MembershipStatus.approved;
    final isPending = status == MembershipStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(community.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(community.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: isApproved
            ? const Icon(Icons.chevron_right)
            : isPending
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 12)),
                  )
                : ElevatedButton(
                    onPressed: () => _joinCommunity(context, ref, community),
                    child: const Text('Join'),
                  ),
        onTap: isApproved
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CommunityDetailScreen(community: community)),
                );
              }
            : null,
      ),
    );
  }

  Future<void> _joinCommunity(BuildContext context, WidgetRef ref, Community community) async {
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
