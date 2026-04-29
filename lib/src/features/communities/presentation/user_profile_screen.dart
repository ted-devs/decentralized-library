import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:decentralized_library/src/features/auth/domain/app_user.dart';
import 'package:decentralized_library/src/features/communities/domain/membership.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/bookshelf/data/bookshelf_repository.dart';
import 'package:decentralized_library/src/shared/utils/snackbar_utils.dart';

class UserProfileScreen extends ConsumerWidget {
  final AppUser user;
  final Membership? membership;
  final String? prefillBookTitle;

  const UserProfileScreen({
    super.key,
    required this.user,
    this.membership,
    this.prefillBookTitle,
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
            InkWell(
              onTap: () => _launchEmail(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.email_outlined, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      user.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
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
                  DateFormat('MMM yyyy').format(membership?.joinedAt ?? user.createdAt),
                ),
              ],
            ),
            
            if (membership != null && membership!.status == MembershipStatus.approved) ...[
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
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final String subject = Uri.encodeComponent(
      prefillBookTitle != null 
        ? 'Decentralized Library - Inquiry regarding "$prefillBookTitle"'
        : 'Decentralized Library - Inquiry'
    );
    final String body = Uri.encodeComponent(
      prefillBookTitle != null
        ? 'Hi ${user.displayName},\n\nI am interested in coordinating the exchange of the book "$prefillBookTitle". Let me know when and where we can meet!\n\nBest regards,'
        : 'Hi ${user.displayName},\n\n'
    );
    
    final Uri mailUri = Uri.parse('mailto:${user.email}?subject=$subject&body=$body');
    
    if (await canLaunchUrl(mailUri)) {
      await launchUrl(mailUri);
    } else {
      if (context.mounted) {
        AppSnackBar.show(context, 'Could not open email app.');
      }
    }
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

    if (confirm == true && membership != null) {
      await ref.read(communityRepositoryProvider).leaveCommunity(membership!.id);
      if (context.mounted) {
        Navigator.pop(context); // Close profile screen
        AppSnackBar.show(context, '${user.displayName} has been removed.');
      }
    }
  }
}
