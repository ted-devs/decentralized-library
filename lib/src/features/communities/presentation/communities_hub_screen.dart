import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/communities/domain/community.dart';
import 'package:decentralized_library/src/features/communities/domain/membership.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/features/auth/domain/app_user.dart';
import 'community_detail_screen.dart';
import 'community_info_screen.dart';
import 'create_community_screen.dart';

class CommunitiesHubScreen extends ConsumerWidget {
  const CommunitiesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final appUser = ref.watch(appUserProvider).value;
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
              final managedCommunities = allCommunities.where((c) => c.adminId == user?.uid).toList();
              final joinedCommunities = allCommunities.where((c) => membershipMap[c.id]?.status == MembershipStatus.approved && c.adminId != user?.uid).toList();
              final pendingCommunities = allCommunities.where((c) => membershipMap[c.id]?.status == MembershipStatus.pending).toList();
              final otherCommunities = allCommunities.where((c) => !membershipMap.containsKey(c.id) && c.adminId != user?.uid).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (managedCommunities.isNotEmpty) ...[
                    _buildSectionHeader('Managed Communities'),
                    const SizedBox(height: 8),
                    ...managedCommunities.map((c) => _buildCommunityCard(context, ref, c, membershipMap[c.id], appUser)),
                    const SizedBox(height: 24),
                  ],
                  if (joinedCommunities.isNotEmpty) ...[
                    _buildSectionHeader('Joined Communities'),
                    const SizedBox(height: 8),
                    ...joinedCommunities.map((c) => _buildCommunityCard(context, ref, c, membershipMap[c.id], appUser)),
                    const SizedBox(height: 24),
                  ],
                  if (pendingCommunities.isNotEmpty) ...[
                    _buildSectionHeader('Pending Requests'),
                    const SizedBox(height: 8),
                    ...pendingCommunities.map((c) => _buildCommunityCard(context, ref, c, membershipMap[c.id], appUser)),
                    const SizedBox(height: 24),
                  ],
                  if (otherCommunities.isNotEmpty) ...[
                    _buildSectionHeader('Discover More'),
                    const SizedBox(height: 8),
                    ...otherCommunities.map((c) => _buildCommunityCard(context, ref, c, membershipMap[c.id], appUser)),
                  ],
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

  Widget _buildCommunityCard(BuildContext context, WidgetRef ref, Community community, Membership? membership, AppUser? appUser) {
    final status = membership?.status;
    final isApproved = status == MembershipStatus.approved;
    final isPending = status == MembershipStatus.pending;
    final isPinned = appUser?.pinnedCommunities.contains(community.id) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(community.name, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (community.adminId == appUser?.uid)
              Badge(
                isLabelVisible: ref.watch(communityPendingRequestsProvider(community.id)).value?.isNotEmpty ?? false,
                child: const SizedBox.shrink(),
              ),
          ],
        ),
        subtitle: Text(community.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (appUser != null && (isApproved || community.adminId == appUser.uid))
              IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 20,
                  color: isPinned ? Colors.blue : Colors.grey,
                ),
                onPressed: () async {
                  try {
                    await ref.read(communityRepositoryProvider).togglePinCommunity(
                      appUser.uid,
                      community.id,
                      !isPinned,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                      );
                    }
                  }
                },
              ),
            isApproved
                ? const Icon(Icons.arrow_forward_ios_rounded, size: 16)
                : isPending
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 12)),
                      )
                    : const Icon(Icons.info_outline_rounded, color: Colors.grey),
          ],
        ),
        onTap: () {
          if (isApproved) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CommunityDetailScreen(community: community)),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CommunityInfoScreen(community: community)),
            );
          }
        },
      ),
    );
  }
}
