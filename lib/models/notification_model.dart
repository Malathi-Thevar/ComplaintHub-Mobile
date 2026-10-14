import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String description;
  final String timeAgo;
  final bool isRead;
  final bool isNew;
  final String? complaintId;
  final bool isAnnouncement;
  final DateTime? timestamp;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.description,
    required this.timeAgo,
    this.isRead = false,
    this.isNew = true,
    this.complaintId,
    this.isAnnouncement = false,
    this.timestamp,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? description,
    String? timeAgo,
    bool? isRead,
    bool? isNew,
    String? complaintId,
    bool? isAnnouncement,
    DateTime? timestamp,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      timeAgo: timeAgo ?? this.timeAgo,
      isRead: isRead ?? this.isRead,
      isNew: isNew ?? this.isNew,
      complaintId: complaintId ?? this.complaintId,
      isAnnouncement: isAnnouncement ?? this.isAnnouncement,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isRead': isRead,
      'isNew': isNew,
      if (complaintId != null) 'complaintId': complaintId,
      'isAnnouncement': isAnnouncement,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }

  factory NotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    DateTime? dt;
    String computedTimeAgo = 'Just now';

    if (data['timestamp'] is Timestamp) {
      dt = (data['timestamp'] as Timestamp).toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) {
        computedTimeAgo = 'Just now';
      } else if (diff.inHours < 1) {
        computedTimeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        computedTimeAgo = '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        computedTimeAgo = '${diff.inDays}d ago';
      } else {
        computedTimeAgo = '${dt.day}/${dt.month}/${dt.year}';
      }
    }

    return NotificationModel(
      id: snapshot.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      timeAgo: computedTimeAgo,
      isRead: data['isRead'] as bool? ?? false,
      isNew: data['isNew'] as bool? ?? false,
      complaintId: data['complaintId'] as String?,
      isAnnouncement: data['isAnnouncement'] as bool? ?? false,
      timestamp: dt,
    );
  }
}
