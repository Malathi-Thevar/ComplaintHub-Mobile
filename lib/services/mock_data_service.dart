import 'package:flutter/material.dart';
import '../models/complaint_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';

class MockDataService extends ChangeNotifier {
  static final MockDataService _instance = MockDataService._internal();
  static MockDataService get instance => _instance;

  MockDataService._internal() {
    _initMockData();
  }

  late UserModel _currentUser;
  late List<ComplaintModel> _complaints;
  late List<NotificationModel> _notifications;

  UserModel get currentUser => _currentUser;
  List<ComplaintModel> get complaints {
    final uid = _currentUser.uid;
    if (uid != null && uid.isNotEmpty) {
      return List.unmodifiable(
        _complaints.where((c) => c.userId == null || c.userId == uid),
      );
    }
    return List.unmodifiable(_complaints);
  }
  List<NotificationModel> get notifications => List.unmodifiable(_notifications);

  int get totalCount => complaints.length;
  int get pendingCount =>
      complaints.where((c) => c.status == ComplaintStatus.pending).length;
  int get inProgressCount =>
      complaints.where((c) => c.status == ComplaintStatus.inProgress).length;
  int get resolvedCount =>
      complaints.where((c) => c.status == ComplaintStatus.resolved).length;
  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead && !n.isAnnouncement && n.complaintId != null).length;

  void _initMockData() {
    _currentUser = const UserModel(
      registerNumber: '',
      fullName: '',
      department: '',
      email: '',
      academicYear: '',
    );

    _complaints = [];
    _notifications = [];
  }

  void submitComplaint({
    String? id,
    required String category,
    required String department,
    required String subject,
    required String description,
    String? attachmentName,
    String? userId,
  }) {
    final newId = id ?? '#CH${1001 + _complaints.length}';
    final now = DateTime.now();

    final newComplaint = ComplaintModel(
      id: newId,
      userId: userId ?? _currentUser.uid,
      category: category,
      concernedDepartment: department,
      subject: subject,
      description: description,
      status: ComplaintStatus.pending,
      submittedAt: now,
      attachmentName: attachmentName,
      timeline: [
        TimelineEvent(
          title: 'Complaint Submitted',
          description: 'Complaint submitted successfully.',
          timestamp: 'Just now',
          isCompleted: true,
        ),
        const TimelineEvent(
          title: 'Under Review',
          description: 'Awaiting department review.',
          timestamp: 'Pending',
          isActive: true,
        ),
        const TimelineEvent(
          title: 'In Progress',
          description: 'Department resolution work.',
          timestamp: 'Pending',
          isCompleted: false,
        ),
        const TimelineEvent(
          title: 'Resolved',
          description: 'Issue resolution.',
          timestamp: 'Pending',
          isCompleted: false,
        ),
      ],
    );

    _complaints.insert(0, newComplaint);

    _notifications.insert(
      0,
      NotificationModel(
        id: 'n_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Your complaint $newId was successfully registered.',
        description:
            'Your grievance regarding "$subject" has been sent to the $department.',
        timeAgo: 'Just now',
        isRead: false,
        isNew: true,
        complaintId: newId,
      ),
    );

    notifyListeners();
  }

  void addFollowUp(String complaintId, String followUpNote) {
    final index = _complaints.indexWhere((c) => c.id == complaintId);
    if (index != -1) {
      final complaint = _complaints[index];
      final updatedTimeline = List<TimelineEvent>.from(complaint.timeline)
        ..add(
          TimelineEvent(
            title: 'Follow-up Added',
            description: followUpNote,
            timestamp: 'Just now',
            isCompleted: true,
          ),
        );
      _complaints[index] = complaint.copyWith(timeline: updatedTimeline);
      notifyListeners();
    }
  }

  void markAllNotificationsRead() {
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true, isNew: false))
        .toList();
    notifyListeners();
  }

  void updateProfile({
    required String fullName,
    required String department,
    required String email,
  }) {
    _currentUser = _currentUser.copyWith(
      fullName: fullName,
      department: department,
      email: email,
    );
    notifyListeners();
  }

  void setUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  void clearUserData() {
    _currentUser = const UserModel(
      registerNumber: '',
      fullName: '',
      department: '',
      email: '',
      academicYear: '',
    );
    _complaints = [];
    _notifications = [];
    notifyListeners();
  }

  void reset() {
    _initMockData();
    notifyListeners();
  }

  void syncWithFirebaseUser({String? email, String? displayName, String? uid}) {
    if (email != null && email.isNotEmpty) {
      final prevEmail = _currentUser.email;
      if (prevEmail.isNotEmpty && prevEmail != email) {
        _complaints = [];
        _notifications = [];
      }
      _currentUser = _currentUser.copyWith(
        uid: uid ?? _currentUser.uid,
        email: email,
        fullName: (displayName != null && displayName.isNotEmpty)
            ? displayName
            : _currentUser.fullName,
      );
      notifyListeners();
    }
  }
}
