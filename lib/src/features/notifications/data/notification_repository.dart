import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/app_notification.dart';

final notificationRepositoryProvider = Provider((ref) => NotificationRepository(FirebaseFirestore.instance));

class NotificationRepository {
  final FirebaseFirestore _firestore;
  NotificationRepository(this._firestore);

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
            .toList();
          
          // Sort in memory to avoid needing a Firestore composite index
          notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return notifications;
        });
  }

  Stream<int> watchUnreadCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final unread = await _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> sendNotification(AppNotification notification) async {
    await _firestore.collection('notifications').add(notification.toMap());
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  Future<void> deleteAllReadNotifications(String userId) async {
    final read = await _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: true)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in read.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

// Providers
final unreadNotificationsCountProvider = StreamProvider.family<int, String>((ref, userId) {
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(userId);
});

final userNotificationsProvider = StreamProvider.family<List<AppNotification>, String>((ref, userId) {
  return ref.watch(notificationRepositoryProvider).watchNotifications(userId);
});
