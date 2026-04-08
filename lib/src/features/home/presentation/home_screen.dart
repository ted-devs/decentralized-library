import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_service.dart';
import '../../bookshelf/data/bookshelf_repository.dart';
import '../../communities/presentation/community_detail_screen.dart';
import '../../communities/data/community_repository.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/presentation/notifications_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).value;
    final bookshelfAsync = ref.watch(bookshelfProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: (ref.watch(unreadNotificationsCountProvider(appUser?.uid ?? '')).value ?? 0) > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Text(
              'Hello, ${appUser?.displayName ?? 'User'}!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (appUser != null && appUser.city.isNotEmpty)
              Text(
                '${appUser.city}, ${appUser.country}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            const SizedBox(height: 24),

            // Summary Stats Cards
            bookshelfAsync.when(
              data: (items) {
                final borrowedCount = items.where((i) => i.isBorrowed).length;
                final lentCount = items.where((i) => i.isLent).length;
                final ownedCount = items.where((i) => !i.isBorrowed).length;

                return Row(
                  children: [
                    _buildStatCard(
                      context,
                      'Borrowed',
                      borrowedCount,
                      Icons.add_circle,
                      Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      context,
                      'Lent',
                      lentCount,
                      Icons.remove_circle,
                      Colors.red,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      context,
                      'Owned',
                      ownedCount,
                      Icons.menu_book,
                      Colors.blue,
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, st) => Text('Error loading stats: $e'),
            ),
            const SizedBox(height: 32),

            // Pinned Communities (Quick Access)
            if (appUser != null && appUser.pinnedCommunities.isNotEmpty) ...[
              _buildPinnedCommunitiesRow(
                context,
                ref,
                appUser.pinnedCommunities,
              ),
              const SizedBox(height: 32),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedCommunitiesRow(
    BuildContext context,
    WidgetRef ref,
    List<String> pinnedIds,
  ) {
    final allCommunitiesAsync = ref.watch(allCommunitiesProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pinned Communities',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        allCommunitiesAsync.when(
          data: (communities) {
            final pinned = communities
                .where((c) => pinnedIds.contains(c.id))
                .toList();

            if (pinned.isEmpty) return const SizedBox.shrink();

            return Column(
              children: pinned.map((community) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  color: theme.colorScheme.primaryContainer.withAlpha(40),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      radius: 16,
                      child: Icon(
                        Icons.people_alt_rounded,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    title: Text(
                      community.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      community.adminId == ref.watch(authStateProvider).value?.uid ? 'Manage' : 'View',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CommunityDetailScreen(community: community),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, st) => const Text('Error loading pins'),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
