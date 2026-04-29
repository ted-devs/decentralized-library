import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/domain/app_user.dart';
import '../application/user_settings_service.dart';
import '../../../shared/constants/countries.dart';

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
                        ? Icon(
                            Icons.person,
                            size: 55,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    appUser?.displayName ?? 'Not logged in',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appUser?.email ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  if (appUser?.city.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${appUser!.country}, ${appUser.city}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary.withAlpha(180),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Actions Row: Edit Profile and Membership
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showEditProfileDialog(
                          context,
                          ref,
                          appUser?.displayName ?? '',
                          appUser?.city ?? '',
                          appUser?.country ?? '',
                        ),
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Edit Profile'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Membership Badge
                      GestureDetector(
                        onTap: () => _showTierDetailsSheet(context, ref, appUser),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: appUser?.isAdmin == true
                                ? Colors.deepPurple[50]
                                : appUser?.isPro == true
                                    ? Colors.amber[100]
                                    : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: appUser?.isAdmin == true
                                  ? Colors.deepPurple[700]!
                                  : appUser?.isPro == true
                                      ? Colors.amber[700]!
                                      : Colors.grey[400]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                appUser?.isAdmin == true
                                    ? Icons.shield_rounded
                                    : appUser?.isPro == true
                                        ? Icons.workspace_premium_rounded
                                        : Icons.person_outline_rounded,
                                size: 14,
                                color: appUser?.isAdmin == true
                                    ? Colors.deepPurple[900]
                                    : appUser?.isPro == true
                                        ? Colors.amber[900]
                                        : Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                appUser?.tier.label.toUpperCase() ?? 'FREE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: appUser?.isAdmin == true
                                      ? Colors.deepPurple[900]
                                      : appUser?.isPro == true
                                          ? Colors.amber[900]
                                          : Colors.grey[700],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(height: 1),

            // Sub-Settings
            _SettingsTile(
              leading: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
                color: theme.colorScheme.primary,
              ),
              title: 'Dark Mode',
              subtitle: 'Current: ${themeMode.name.toUpperCase()}',
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (_) =>
                    ref.read(themeModeProvider.notifier).toggleTheme(),
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
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign Out'),
                      ),
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

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
    String currentCity,
    String currentCountry,
  ) {
    final nameController = TextEditingController(text: currentName);
    final cityController = TextEditingController(text: currentCity);
    String selectedCountry = currentCountry;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Display Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCountry.isEmpty ? null : selectedCountry,
                decoration: const InputDecoration(labelText: 'Country'),
                items: countries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => selectedCountry = val ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _mockUpdateProfile(
                ref,
                nameController.text,
                cityController.text,
                selectedCountry,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTierDetailsSheet(
    BuildContext context,
    WidgetRef ref,
    AppUser? user,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Text(
              'Membership Tiers',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildTierCard(
                    context,
                    tier: UserTier.free,
                    isCurrent: user?.tier == UserTier.free,
                    color: Colors.grey,
                    features: [
                      'Join up to 3 communities',
                      'Borrow up to 5 books at once',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTierCard(
                    context,
                    tier: UserTier.pro,
                    isCurrent: user?.tier == UserTier.pro,
                    color: Colors.amber[700]!,
                    features: [
                      'Unlimited community memberships',
                      'Borrow up to 10 books at once',
                      'Premium badge on profile',
                    ],
                    onAction: user?.tier == UserTier.free
                        ? () {
                            _mockUpdatePro(ref, true);
                            Navigator.pop(context);
                          }
                        : null,
                    actionLabel: 'Go Pro',
                  ),
                  const SizedBox(height: 16),
                  _buildTierCard(
                    context,
                    tier: UserTier.admin,
                    isCurrent: user?.tier == UserTier.admin,
                    color: Colors.deepPurple,
                    features: [
                      'All Pro benefits included',
                      'Create and manage communities',
                      'Exclusive Administrator status',
                    ],
                    onAction: user?.tier != UserTier.admin
                        ? () {
                            // In a real app this would be a special role
                            _mockUpdateAdmin(ref, true);
                            Navigator.pop(context);
                          }
                        : null,
                    actionLabel: 'Become Admin',
                  ),
                  const SizedBox(height: 24),
                  if (user?.tier != UserTier.free)
                    Center(
                      child: TextButton(
                        onPressed: () => _cancelSubscription(context, ref, user!),
                        child: Text(
                          'Cancel Subscription',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelSubscription(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    if (user.isAdmin) {
      final communities = await ref
          .read(firestoreProvider)
          .collection('communities')
          .where('adminId', isEqualTo: user.uid)
          .get();

      if (communities.docs.isNotEmpty) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Action Required'),
              content: const Text(
                'As an Administrator, you cannot downgrade while managing active communities. Please delete your communities first.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    if (context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Subscription?'),
          content: const Text(
            'Are you sure you want to revert to the Free tier? You will lose all premium benefits and your borrowing limits will be reduced.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Premium'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Cancel Subscription',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref
            .read(firestoreProvider)
            .collection('users')
            .doc(user.uid)
            .update({
          'isPro': false,
          'isAdmin': false,
        });
        if (context.mounted) {
          Navigator.pop(context); // Close sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription canceled successfully.')),
          );
        }
      }
    }
  }

  Widget _buildTierCard(
    BuildContext context, {
    required UserTier tier,
    required bool isCurrent,
    required Color color,
    required List<String> features,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: isCurrent ? Border.all(color: color, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isCurrent ? 15 : 5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tier.label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (isCurrent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'CURRENT',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(f, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              )),
          if (onAction != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel ?? 'Upgrade'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _mockUpdatePro(WidgetRef ref, bool isPro) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    await ref.read(firestoreProvider).collection('users').doc(user.uid).update({
      'isPro': isPro,
      'isAdmin': false,
    });
  }

  Future<void> _mockUpdateAdmin(WidgetRef ref, bool isAdmin) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    await ref.read(firestoreProvider).collection('users').doc(user.uid).update({
      'isPro': true,
      'isAdmin': isAdmin,
    });
  }

  Future<void> _mockUpdateProfile(
    WidgetRef ref,
    String newName,
    String newCity,
    String newCountry,
  ) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    await ref.read(firestoreProvider).collection('users').doc(user.uid).update({
      'displayName': newName,
      'city': newCity,
      'country': newCountry,
    });
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
      title: Text(
        title,
        style: TextStyle(color: titleColor, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
