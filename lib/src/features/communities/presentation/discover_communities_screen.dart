import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'community_info_screen.dart';

class DiscoverCommunitiesScreen extends ConsumerStatefulWidget {
  const DiscoverCommunitiesScreen({super.key});

  @override
  ConsumerState<DiscoverCommunitiesScreen> createState() => _DiscoverCommunitiesScreenState();
}

class _DiscoverCommunitiesScreenState extends ConsumerState<DiscoverCommunitiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final allCommunitiesAsync = ref.watch(allCommunitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Libraries'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, city, or organization...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: allCommunitiesAsync.when(
              data: (communities) {
                final query = _searchQuery.toLowerCase();
                
                // Filter for public communities and match search query
                final results = communities.where((c) {
                  if (!c.isPublic) return false;
                  if (c.adminId == user?.uid) return false; // Hide if they own it

                  if (query.isEmpty) return true;

                  return c.name.toLowerCase().contains(query) ||
                      c.city.toLowerCase().contains(query) ||
                      c.country.toLowerCase().contains(query) ||
                      (c.organization?.toLowerCase().contains(query) ?? false);
                }).toList();

                // Sort results alphabetically by default
                results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                if (results.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No public libraries available right now.'
                          : 'No libraries match your search.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final community = results[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.library_books,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(community.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${community.city}, ${community.country}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CommunityInfoScreen(community: community),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error loading communities: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
