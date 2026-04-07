import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  joinRequest,         // To Admin: "User X wants to join Community Y"
  membershipApproved,  // To User: "Your request to join Community Y was approved"
  borrowRequest,       // To Owner: "User X wants to borrow Book Z"
  borrowApproved,      // To Borrower: "Your request for Book Z was approved"
  bookReturned,        // To Owner: "User X returned Book Z"
  general,             // General system update
}

class AppNotification {
  final String id;
  final String recipientId;
  final String? senderId;
  final NotificationType type;
  final String title;
  final String body;
  final String? relatedId; // communityId or transactionId
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.recipientId,
    this.senderId,
    required this.type,
    required this.title,
    required this.body,
    this.relatedId,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'senderId': senderId,
      'type': type.name,
      'title': title,
      'body': body,
      'relatedId': relatedId,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      recipientId: map['recipientId'] ?? '',
      senderId: map['senderId'],
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.general,
      ),
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      relatedId: map['relatedId'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }
}
