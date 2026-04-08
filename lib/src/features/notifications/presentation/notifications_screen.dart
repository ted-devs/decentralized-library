import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in.')));

    final notificationsAsync = ref.watch(userNotificationsProvider(user.uid));
    final repo = ref.read(notificationRepositoryProvider);
    Future<void> _showDeleteReadConfirmation(BuildContext context, String userId) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Read Notifications?'),
          content: const Text('This will permanently remove all notifications you have already read. This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await repo.deleteAllReadNotifications(userId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Read notifications deleted.')),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: () => _showDeleteReadConfirmation(context, user.uid),
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Delete all read',
          ),
          TextButton(
            onPressed: () => repo.markAllAsRead(user.uid),
            child: const Text('Mark all as read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No notifications yet.'),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.horizontal,
                background: Container(
                  color: notification.isRead ? Colors.blue[100] : Colors.blue[700],
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(
                    notification.isRead ? Icons.mark_as_unread : Icons.done_all,
                    color: notification.isRead ? Colors.blue[900] : Colors.white,
                  ),
                ),
                secondaryBackground: Container(
                  color: Colors.red[700],
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    // Swipe Right: Toggle Read Status
                    await repo.updateReadStatus(notification.id, !notification.isRead);
                    return false; // Do not dismiss
                  }
                  // Swipe Left: Proceed to delete
                  return true;
                },
                onDismissed: (direction) {
                  if (direction == DismissDirection.endToStart) {
                    repo.deleteNotification(notification.id);
                  }
                },
                child: _NotificationTile(
                  notification: notification,
                  onRead: () => repo.markAsRead(notification.id),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onRead;

  const _NotificationTile({required this.notification, required this.onRead});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat.jm().add_MMMd().format(notification.timestamp);

    return ListTile(
      tileColor: notification.isRead ? null : theme.colorScheme.primary.withAlpha(10),
      leading: CircleAvatar(
        backgroundColor: _getCategoryColor(notification.type, theme),
        child: Icon(_getCategoryIcon(notification.type), color: Colors.white, size: 20),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(notification.body, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
      onTap: () {
        if (!notification.isRead) onRead();
        // TODO: Handle deep-linking to transaction or community
      },
    );
  }

  IconData _getCategoryIcon(NotificationType type) {
    switch (type) {
      case NotificationType.joinRequest: return Icons.person_add_rounded;
      case NotificationType.membershipApproved: return Icons.verified_user_rounded;
      case NotificationType.borrowRequest: return Icons.swap_horizontal_circle_rounded;
      case NotificationType.borrowApproved: return Icons.check_circle_rounded;
      case NotificationType.bookReturned: return Icons.keyboard_return_rounded;
      case NotificationType.general: return Icons.info_outline_rounded;
    }
  }

  Color _getCategoryColor(NotificationType type, ThemeData theme) {
    switch (type) {
      case NotificationType.joinRequest: return Colors.blue;
      case NotificationType.membershipApproved: return Colors.green;
      case NotificationType.borrowRequest: return Colors.orange;
      case NotificationType.borrowApproved: return Colors.green;
      case NotificationType.bookReturned: return Colors.purple;
      case NotificationType.general: return theme.colorScheme.primary;
    }
  }
}
