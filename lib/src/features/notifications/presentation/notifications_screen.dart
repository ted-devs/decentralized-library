import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';
import 'package:intl/intl.dart';

import 'package:flutter_slidable/flutter_slidable.dart';

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
              return Slidable(
                key: Key(notification.id),
                startActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (_) => repo.updateReadStatus(notification.id, !notification.isRead),
                      backgroundColor: notification.isRead ? Colors.blue.withAlpha(50) : Colors.blue[700]!,
                      foregroundColor: notification.isRead ? Colors.blue[900] : Colors.white,
                      icon: notification.isRead ? Icons.mark_as_unread : Icons.done_all,
                      label: notification.isRead ? 'Unread' : 'Read',
                    ),
                  ],
                ),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (_) => repo.deleteNotification(notification.id),
                      backgroundColor: Colors.red[700]!,
                      foregroundColor: Colors.white,
                      icon: Icons.delete_outline,
                      label: 'Delete',
                    ),
                  ],
                ),
                child: Builder(
                  builder: (context) {
                    return Listener(
                      onPointerUp: (event) {
                        final slidable = Slidable.of(context);
                        if (slidable != null) {
                          final ratio = slidable.ratio;
                          // If opened enough (ratio > 0.2 or ratio < -0.2)
                          if (ratio > 0.15) {
                            // Start Action Pane (Toggle)
                            repo.updateReadStatus(notification.id, !notification.isRead);
                            slidable.close();
                          } else if (ratio < -0.15) {
                            // End Action Pane (Delete)
                            repo.deleteNotification(notification.id);
                            // No need to close if it's going to be deleted, but safe to do
                            slidable.close();
                          }
                        }
                      },
                      child: _NotificationTile(
                        notification: notification,
                        onRead: () => repo.markAsRead(notification.id),
                      ),
                    );
                  },
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
