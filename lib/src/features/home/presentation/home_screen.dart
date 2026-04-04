import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_service.dart';
import '../../bookshelf/presentation/bookshelf_screen.dart';
import '../../bookshelf/data/bookshelf_repository.dart';

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
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              // Navigate to profile or show simple profile info
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
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
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${appUser?.city}, ${appUser?.country}',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
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
                    _buildStatCard(context, 'Borrowed', borrowedCount, Icons.add_circle, Colors.green),
                    const SizedBox(width: 12),
                    _buildStatCard(context, 'Lent', lentCount, Icons.remove_circle, Colors.red),
                    const SizedBox(width: 12),
                    _buildStatCard(context, 'Owned', ownedCount, Icons.menu_book, Colors.blue),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error: $e'),
            ),
            const SizedBox(height: 32),

            // Navigation Links
            Text('Quick Access', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildNavLink(
              context,
              'My Bookshelf',
              'Manage your personal collection.',
              Icons.library_books,
              const BookshelfScreen(),
            ),
            _buildNavLink(
              context,
              'Communities',
              'Join or manage local library groups.',
              Icons.people,
              const Placeholder(child: Scaffold(body: Center(child: Text('Communities Screen Placeholder')))),
            ),
            _buildNavLink(
              context,
              'Borrowing Requests',
              'Check status of pending requests.',
              Icons.request_page,
              const Placeholder(child: Scaffold(body: Center(child: Text('Requests Screen Placeholder')))),
            ),
            _buildNavLink(
              context,
              'Settings',
              'Dark mode and Pro status.',
              Icons.settings,
              const Placeholder(child: Scaffold(body: Center(child: Text('Settings Screen Placeholder')))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, int count, IconData icon, Color color) {
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
            Text(count.toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavLink(BuildContext context, String title, String subtitle, IconData icon, Widget destination) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination)),
      ),
    );
  }
}
