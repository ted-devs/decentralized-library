import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:decentralized_library/src/features/auth/domain/app_user.dart';
import 'package:decentralized_library/src/features/communities/domain/membership.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
import 'package:decentralized_library/src/features/bookshelf/domain/book.dart';

class UserProfileScreen extends ConsumerWidget {
  final AppUser user;
  final Membership membership;

  const UserProfileScreen({
    super.key,
    required this.user,
    required this.membership,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(memberBooksProvider(user.uid));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),
            const SizedBox(height: 16),
            Text(
              user.displayName,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              user.email,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  context,
                  'Books Shared',
                  booksAsync.when(
                    data: (books) => books.where((b) => b.isShareable).length.toString(),
                    loading: () => '...',
                    error: (_, __) => '?',
                  ),
                ),
                _buildStatItem(
                  context,
                  'Joined',
                  DateFormat('MMM yyyy').format(membership.joinedAt),
                ),
              ],
            ),
            
            const SizedBox(height: 48),
            
            // Admin Actions
            Card(
              color: Colors.red.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.red.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Admin Actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Removing this member will revoke their access to the community library and remove their books from the collection.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showRemoveConfirmation(context, ref),
                      icon: const Icon(Icons.person_remove_rounded),
                      label: const Text('Remove from Community'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Future<void> _showRemoveConfirmation(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Are you sure you want to remove ${user.displayName} from this community?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(communityRepositoryProvider).leaveCommunity(membership.id);
      if (context.mounted) {
        Navigator.pop(context); // Close profile screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.displayName} has been removed.')),
        );
      }
    }
  }
}
