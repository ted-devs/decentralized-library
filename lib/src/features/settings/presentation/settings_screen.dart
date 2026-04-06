import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_service.dart';
import '../application/user_settings_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final appUser = ref.watch(appUserProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: Icon(
              themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Dark Mode'),
            subtitle: Text('Current: ${themeMode.name.toUpperCase()}'),
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggleTheme(),
            ),
          ),
          const Divider(),
          const _SectionHeader(title: 'Account & Membership'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(appUser?.displayName ?? 'Not logged in'),
            subtitle: Text(appUser?.email ?? ''),
          ),
          ListTile(
            leading: Icon(
              Icons.stars_rounded,
              color: appUser?.isPro == true ? Colors.amber : Colors.grey,
            ),
            title: const Text('Premium Status'),
            subtitle: Text(appUser?.isPro == true ? 'Pro Member' : 'Standard Member'),
            trailing: appUser?.isPro == false
                ? ElevatedButton(
                    onPressed: () => _showGoProDialog(context, ref),
                    child: const Text('Go Pro'),
                  )
                : const Icon(Icons.check_circle, color: Colors.green),
          ),
          const Divider(),
          const _SectionHeader(title: 'App Info'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.0 (BETA)'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out?'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out')),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showGoProDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go Pro!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upgrade to unlock premium features:'),
            SizedBox(height: 12),
            _ProFeature(text: 'Borrow up to 10 books (Standard: 3)'),
            _ProFeature(text: 'Create unlimited communities'),
            _ProFeature(text: 'Exclusive badge on profile'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          ElevatedButton(
            onPressed: () {
              _mockUpgrade(ref);
              Navigator.pop(context);
            },
            child: const Text('Upgrade (Mock)'),
          ),
        ],
      ),
    );
  }

  Future<void> _mockUpgrade(WidgetRef ref) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    await ref.read(firestoreProvider).collection('users').doc(user.uid).update({'isPro': true});
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ProFeature extends StatelessWidget {
  final String text;
  const _ProFeature({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
