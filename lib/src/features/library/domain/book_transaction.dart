import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionStatus {
  requested,
  approved,
  pickedUp,
  returned,
  canceled,
  overdue,
}

class BookTransaction {
  final String id;
  final String bookId;
  final String ownerId;
  final String borrowerId;
  final String communityId;
  final TransactionStatus status;
  final int durationWeeks;
  final DateTime? requestedDate;
  final DateTime? approvedDate;
  final DateTime? pickedUpDate;
  final DateTime? returnedDate;
  final DateTime? canceledDate;

  BookTransaction({
    required this.id,
    required this.bookId,
    required this.ownerId,
    required this.borrowerId,
    required this.communityId,
    required this.status,
    required this.durationWeeks,
    this.requestedDate,
    this.approvedDate,
    this.pickedUpDate,
    this.returnedDate,
    this.canceledDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'ownerId': ownerId,
      'borrowerId': borrowerId,
      'communityId': communityId,
      'status': status.name,
      'durationWeeks': durationWeeks,
      'requestedDate': requestedDate != null ? Timestamp.fromDate(requestedDate!) : null,
      'approvedDate': approvedDate != null ? Timestamp.fromDate(approvedDate!) : null,
      'pickedUpDate': pickedUpDate != null ? Timestamp.fromDate(pickedUpDate!) : null,
      'returnedDate': returnedDate != null ? Timestamp.fromDate(returnedDate!) : null,
      'canceledDate': canceledDate != null ? Timestamp.fromDate(canceledDate!) : null,
    };
  }

  bool isOverdue() {
    if (status != TransactionStatus.pickedUp || pickedUpDate == null) return false;
    final dueDate = pickedUpDate!.add(Duration(days: durationWeeks * 7));
    return DateTime.now().isAfter(dueDate);
  }

  static TransactionStatus _parseStatus(String statusStr) {
    final normalized = statusStr.toLowerCase().replaceAll('_', '');
    for (var value in TransactionStatus.values) {
      if (value.name.toLowerCase().replaceAll('_', '') == normalized) {
        return value;
      }
    }
    return TransactionStatus.requested;
  }

  factory BookTransaction.fromMap(Map<String, dynamic> map, String id) {
    return BookTransaction(
      id: id,
      bookId: map['bookId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      borrowerId: map['borrowerId'] ?? '',
      communityId: map['communityId'] ?? '',
      status: _parseStatus(map['status'] ?? 'requested'),
      durationWeeks: map['durationWeeks'] ?? 4,
      requestedDate: (map['requestedDate'] as Timestamp?)?.toDate(),
      approvedDate: (map['approvedDate'] as Timestamp?)?.toDate(),
      pickedUpDate: (map['pickedUpDate'] as Timestamp?)?.toDate(),
      returnedDate: (map['returnedDate'] as Timestamp?)?.toDate(),
      canceledDate: (map['canceledDate'] as Timestamp?)?.toDate(),
    );
  }
}
