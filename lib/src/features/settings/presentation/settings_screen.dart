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
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Centered Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: theme.colorScheme.primary.withAlpha(50),
                    backgroundImage: appUser?.photoUrl.isNotEmpty == true 
                        ? NetworkImage(appUser!.photoUrl) 
                        : null,
                    child: appUser?.photoUrl.isEmpty == true 
                        ? Icon(Icons.person, size: 55, color: theme.colorScheme.primary) 
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 48), // Spacer to balance the edit icon
                      Text(
                        appUser?.displayName ?? 'Not logged in',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showEditNameDialog(context, ref, appUser?.displayName ?? ''),
                        tooltip: 'Edit name',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appUser?.email ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  if (appUser?.city.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${appUser!.city}, ${appUser.country}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary.withAlpha(180),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Membership Badge
                  GestureDetector(
                    onTap: () {
                      if (appUser?.isPro == true) {
                        _showCancelProDialog(context, ref);
                      } else {
                        _showGoProDialog(context, ref);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: appUser?.isPro == true ? Colors.amber[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: appUser?.isPro == true ? Colors.amber[700]! : Colors.grey[400]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            appUser?.isPro == true ? Icons.stars_rounded : Icons.person_outline,
                            size: 18,
                            color: appUser?.isPro == true ? Colors.amber[800] : Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            appUser?.isPro == true ? 'PRO MEMBER' : 'FREE PLAN',
                            style: TextStyle(
                              color: appUser?.isPro == true ? Colors.amber[900] : Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(height: 1),
            
            // Sub-Settings
            _SettingsTile(
              leading: Icon(
                themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                color: theme.colorScheme.primary,
              ),
              title: 'Dark Mode',
              subtitle: 'Current: ${themeMode.name.toUpperCase()}',
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggleTheme(),
              ),
            ),
            const Divider(height: 1, indent: 56),
            _SettingsTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: 'App Info',
              subtitle: 'Version 1.0.0 (BETA)',
              onTap: () {}, // Show app info details or license
            ),
            const Divider(height: 1),
            const SizedBox(height: 40),
            
            // Sign Out Option at the Bottom
            _SettingsTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: 'Sign Out',
              titleColor: Colors.red,
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Display Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _mockUpdateName(ref, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
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
              _mockUpdatePro(ref, true);
              Navigator.pop(context);
            },
            child: const Text('Upgrade (Mock)'),
          ),
        ],
      ),
    );
  }

  void _showCancelProDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Pro?'),
        content: const Text('Are you sure you want to downgrade? You will lose access to premium features like increased borrowing limits.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep Pro')),
          TextButton(
            onPressed: () {
              _mockUpdatePro(ref, false);
              Navigator.pop(context);
            },
            child: const Text('Cancel Subscription', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _mockUpdatePro(WidgetRef ref, bool isPro) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    await ref.read(firestoreProvider).collection('users').doc(user.uid).update({'isPro': isPro});
  }

  Future<void> _mockUpdateName(WidgetRef ref, String newName) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    await ref.read(firestoreProvider).collection('users').doc(user.uid).update({'displayName': newName});
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
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
