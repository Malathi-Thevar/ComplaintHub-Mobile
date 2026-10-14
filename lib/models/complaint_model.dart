import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

enum ComplaintStatus {
  pending,
  inProgress,
  resolved,
  rejected,
}

extension ComplaintStatusExtension on ComplaintStatus {
  String get label {
    switch (this) {
      case ComplaintStatus.pending:
        return 'Pending';
      case ComplaintStatus.inProgress:
        return 'In Progress';
      case ComplaintStatus.resolved:
        return 'Resolved';
      case ComplaintStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case ComplaintStatus.pending:
        return AppColors.statusPending;
      case ComplaintStatus.inProgress:
        return AppColors.statusInProgress;
      case ComplaintStatus.resolved:
        return AppColors.statusResolved;
      case ComplaintStatus.rejected:
        return AppColors.statusRejected;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ComplaintStatus.pending:
        return AppColors.statusPendingBg;
      case ComplaintStatus.inProgress:
        return AppColors.statusInProgressBg;
      case ComplaintStatus.resolved:
        return AppColors.statusResolvedBg;
      case ComplaintStatus.rejected:
        return AppColors.statusRejectedBg;
    }
  }
}

class TimelineEvent {
  final String? id;
  final String title;
  final String description;
  final String timestamp;
  final bool isCompleted;
  final bool isActive;
  final DateTime? rawTimestamp;
  final String? updatedBy;

  const TimelineEvent({
    this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    this.isCompleted = false,
    this.isActive = false,
    this.rawTimestamp,
    this.updatedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'timestamp': timestamp,
      'isCompleted': isCompleted,
      'isActive': isActive,
    };
  }

  factory TimelineEvent.fromFirestore(Map<String, dynamic> data, {String? id}) {
    String formattedTime = '';
    DateTime? raw;
    final ts = data['timestamp'] ?? data['createdAt'];
    if (ts is Timestamp) {
      raw = ts.toDate();
      formattedTime = '${raw.day} ${_monthName(raw.month)} ${raw.year}, ${_formatTime(raw)}';
    } else if (ts is String) {
      final parsed = DateTime.tryParse(ts);
      if (parsed != null) {
        raw = parsed;
        formattedTime = '${raw.day} ${_monthName(raw.month)} ${raw.year}, ${_formatTime(raw)}';
      } else {
        formattedTime = ts;
      }
    }

    if (formattedTime.isEmpty) {
      formattedTime = 'Just now';
    }

    final text = (data['description'] ?? data['message']) as String? ?? '';

    return TimelineEvent(
      id: id,
      title: data['title'] as String? ?? (data.containsKey('authorName') ? 'Follow-up Added' : ''),
      description: text,
      timestamp: formattedTime,
      isCompleted: data['isCompleted'] as bool? ?? true,
      isActive: data['isActive'] as bool? ?? false,
      rawTimestamp: raw,
      updatedBy: (data['updatedBy'] ?? data['authorName']) as String?,
    );
  }

  factory TimelineEvent.fromFollowUpFirestore(Map<String, dynamic> data, {String? id}) {
    String formattedTime = '';
    DateTime? raw;
    final ts = data['timestamp'] ?? data['createdAt'];
    if (ts is Timestamp) {
      raw = ts.toDate();
      formattedTime = '${raw.day} ${_monthName(raw.month)} ${raw.year}, ${_formatTime(raw)}';
    } else if (ts is String) {
      final parsed = DateTime.tryParse(ts);
      if (parsed != null) {
        raw = parsed;
        formattedTime = '${raw.day} ${_monthName(raw.month)} ${raw.year}, ${_formatTime(raw)}';
      } else {
        formattedTime = ts;
      }
    }

    if (formattedTime.isEmpty) {
      formattedTime = 'Just now';
    }

    final text = (data['description'] ?? data['message']) as String? ?? '';

    return TimelineEvent(
      id: id,
      title: data['title'] as String? ?? 'Follow-up Added',
      description: text,
      timestamp: formattedTime,
      isCompleted: true,
      isActive: false,
      rawTimestamp: raw,
      updatedBy: (data['authorName'] ?? data['updatedBy'] ?? data['userId']) as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimelineEvent &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.timestamp == timestamp &&
        other.isCompleted == isCompleted &&
        other.isActive == isActive &&
        other.rawTimestamp == rawTimestamp &&
        other.updatedBy == updatedBy;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        timestamp,
        isCompleted,
        isActive,
        rawTimestamp,
        updatedBy,
      );

  static String formatDateTime(DateTime dt) {
    return '${dt.day} ${_monthName(dt.month)} ${dt.year}, ${_formatTime(dt)}';
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

class ComplaintModel {
  final String id;
  final String? docId;
  final String? userId;
  final String category;
  final String concernedDepartment;
  final String subject;
  final String description;
  final ComplaintStatus status;
  final DateTime submittedAt;
  final String? attachmentName;
  final List<TimelineEvent> timeline;
  final DateTime? updatedAt;

  const ComplaintModel({
    required this.id,
    this.docId,
    this.userId,
    required this.category,
    required this.concernedDepartment,
    required this.subject,
    required this.description,
    required this.status,
    required this.submittedAt,
    this.attachmentName,
    required this.timeline,
    this.updatedAt,
  });

  String get effectiveDocId => docId ?? id;

  static ComplaintStatus parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'inprogress':
        return ComplaintStatus.inProgress;
      case 'resolved':
        return ComplaintStatus.resolved;
      case 'rejected':
        return ComplaintStatus.rejected;
      case 'pending':
      default:
        return ComplaintStatus.pending;
    }
  }

  static String statusToString(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.inProgress:
        return 'inProgress';
      case ComplaintStatus.resolved:
        return 'resolved';
      case ComplaintStatus.rejected:
        return 'rejected';
      case ComplaintStatus.pending:
        return 'pending';
    }
  }

  ComplaintModel copyWith({
    String? id,
    String? docId,
    String? userId,
    String? category,
    String? concernedDepartment,
    String? subject,
    String? description,
    ComplaintStatus? status,
    DateTime? submittedAt,
    String? attachmentName,
    List<TimelineEvent>? timeline,
    DateTime? updatedAt,
  }) {
    return ComplaintModel(
      id: id ?? this.id,
      docId: docId ?? this.docId,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      concernedDepartment: concernedDepartment ?? this.concernedDepartment,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      attachmentName: attachmentName ?? this.attachmentName,
      timeline: timeline ?? this.timeline,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId ?? '',
      'category': category,
      'concernedDepartment': concernedDepartment,
      'subject': subject,
      'description': description,
      if (attachmentName != null) 'attachmentName': attachmentName,
      'status': statusToString(status),
      'submittedAt': Timestamp.fromDate(submittedAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ComplaintModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    List<TimelineEvent> timeline = const [],
    DateTime? fallbackSubmittedAt,
  }) {
    final data = snapshot.data() ?? {};
    final submittedAtVal = data['submittedAt'];
    DateTime submittedDate;
    if (submittedAtVal is Timestamp) {
      submittedDate = submittedAtVal.toDate();
    } else if (submittedAtVal is String) {
      submittedDate = DateTime.tryParse(submittedAtVal) ?? fallbackSubmittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else if (fallbackSubmittedAt != null) {
      submittedDate = fallbackSubmittedAt;
    } else {
      submittedDate = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return ComplaintModel(
      id: data['id'] as String? ?? snapshot.id,
      docId: snapshot.id,
      userId: data['userId'] as String?,
      category: data['category'] as String? ?? 'General',
      concernedDepartment: data['concernedDepartment'] as String? ?? 'General',
      subject: data['subject'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: parseStatus(data['status'] as String?),
      submittedAt: submittedDate,
      attachmentName: data['attachmentName'] as String?,
      timeline: timeline,
      updatedAt: data['updatedAt'] is Timestamp ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComplaintModel) return false;
    if (id != other.id ||
        docId != other.docId ||
        userId != other.userId ||
        category != other.category ||
        concernedDepartment != other.concernedDepartment ||
        subject != other.subject ||
        description != other.description ||
        status != other.status ||
        submittedAt != other.submittedAt ||
        attachmentName != other.attachmentName ||
        updatedAt != other.updatedAt ||
        timeline.length != other.timeline.length) {
      return false;
    }
    for (int i = 0; i < timeline.length; i++) {
      if (timeline[i] != other.timeline[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        docId,
        userId,
        category,
        concernedDepartment,
        subject,
        description,
        status,
        submittedAt,
        attachmentName,
        updatedAt,
        Object.hashAll(timeline),
      );
}
