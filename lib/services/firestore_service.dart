import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/complaint_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'mock_data_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  static FirestoreService get instance => _instance;

  FirestoreService._internal();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _registerNumbersRef =>
      _firestore.collection('registerNumbers');

  CollectionReference<Map<String, dynamic>> get _complaintsRef =>
      _firestore.collection('complaints');

  // =========================================================================
  // 1. User Profile Management & Register Number Uniqueness
  // =========================================================================

  /// Creates a student profile and reserves the register number atomically.
  /// If the register number is already taken by another account, the batch
  /// write will fail due to the Firestore security rule constraint.
  Future<void> createUserProfile({
    required String uid,
    required UserModel user,
  }) async {
    if (!isFirebaseInitialized) {
      MockDataService.instance.setUser(user);
      return;
    }

    final normalizedRegNo = user.registerNumber.trim();
    final batch = _firestore.batch();

    // 1. Reserve register number doc
    final regNoDoc = _registerNumbersRef.doc(normalizedRegNo);
    batch.set(regNoDoc, {
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Create student user profile doc
    final userDoc = _usersRef.doc(uid);
    batch.set(userDoc, {
      'uid': uid,
      'registerNumber': normalizedRegNo,
      'fullName': user.fullName.trim(),
      'department': user.department.trim(),
      'email': user.email.trim().toLowerCase(),
      'academicYear': user.academicYear.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
      MockDataService.instance.setUser(user.copyWith(uid: uid));
    } on FirebaseException catch (e) {
      // Diagnostic logging without exposing sensitive secrets
      assert(() {
        // ignore: avoid_print
        print('Diagnostic: createUserProfile FirebaseException [code: ${e.code}, message: ${e.message}]');
        return true;
      }());
      if (e.code == 'already-exists') {
        throw const FormatException(
          'This register number is already registered with another student account.',
        );
      } else if (e.code == 'permission-denied') {
        throw FormatException(
          'Registration request was rejected by database security rules (${e.code}). Please ensure your details match college records.',
        );
      } else if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw FormatException(
          'Network connection error: Unable to reach Firestore (${e.code}). Please check your internet connection.',
        );
      }
      rethrow;
    }
  }

  /// Fetches the student profile by UID.
  Future<UserModel?> getUserProfile(String uid) async {
    if (!isFirebaseInitialized) {
      return MockDataService.instance.currentUser;
    }

    final currentAuthUid = AuthService.instance.currentUser?.uid;
    debugPrint(
      'Diagnostic: Fetching profile at path="users/$uid" '
      '(authenticated UID="$currentAuthUid", matchesRequested=${currentAuthUid == uid})',
    );

    try {
      final doc = await _usersRef.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        debugPrint('Diagnostic: Successfully loaded profile at path="users/$uid".');
        final user = UserModel.fromFirestore(doc);
        MockDataService.instance.setUser(user);
        return user;
      } else {
        debugPrint('Diagnostic: Profile document does not exist at path="users/$uid".');
      }
    } catch (e) {
      debugPrint('Diagnostic: Error loading profile at path="users/$uid" for authUid="$currentAuthUid": $e');
      rethrow;
    }
    return null;
  }

  /// Real-time stream of the student profile.
  Stream<UserModel?> streamUserProfile(String uid) {
    if (!isFirebaseInitialized) {
      return Stream.value(MockDataService.instance.currentUser);
    }

    return _usersRef.doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        final user = UserModel.fromFirestore(doc);
        MockDataService.instance.setUser(user);
        return user;
      }
      return null;
    });
  }

  /// Updates allowed editable profile fields (fullName, department).
  /// Identity fields (uid, email, registerNumber, createdAt) remain immutable.
  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    required String department,
    String? email,
  }) async {
    if (!isFirebaseInitialized) {
      MockDataService.instance.updateProfile(
        fullName: fullName,
        department: department,
        email: email ?? MockDataService.instance.currentUser.email,
      );
      return;
    }

    final userDoc = _usersRef.doc(uid);
    await userDoc.update({
      'fullName': fullName.trim(),
      'department': department.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final current = MockDataService.instance.currentUser;
    MockDataService.instance.setUser(current.copyWith(
      fullName: fullName.trim(),
      department: department.trim(),
    ));
  }

  // =========================================================================
  // 2. Complaint Submission (Atomic Batch with statusHistory/initial)
  // =========================================================================

  /// Submits a new grievance.
  /// Atomically writes the parent complaint document and its initial status history
  /// in a single WriteBatch, fulfilling strict Firestore security validation.
  Future<String> submitComplaint({
    required String uid,
    required String category,
    required String department,
    required String subject,
    required String description,
    String? attachmentName,
  }) async {
    if (uid.isEmpty || uid == 'mock_student') {
      throw const FormatException('Cannot submit complaint without a valid authenticated student UID.');
    }

    if (!isFirebaseInitialized) {
      final humanId = '#CH${1001 + MockDataService.instance.complaints.length}';
      MockDataService.instance.submitComplaint(
        id: humanId,
        category: category,
        department: department,
        subject: subject,
        description: description,
        attachmentName: attachmentName,
        userId: uid,
      );
      return humanId;
    }

    final complaintDoc = _complaintsRef.doc();
    final humanId = '#CH${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final batch = _firestore.batch();

    // 1. Complaint document
    batch.set(complaintDoc, {
      'id': humanId,
      'userId': uid,
      'category': category.trim(),
      'concernedDepartment': department.trim(),
      'subject': subject.trim(),
      'description': description.trim(),
      if (attachmentName != null && attachmentName.isNotEmpty)
        'attachmentName': attachmentName,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Initial status history document with fixed ID 'initial'
    final initialStatusDoc = complaintDoc.collection('statusHistory').doc('initial');
    batch.set(initialStatusDoc, {
      'title': 'Complaint Submitted',
      'description': 'Complaint submitted successfully.',
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
      'isCompleted': true,
      'isActive': false,
      'updatedBy': uid,
    });

    await batch.commit();

    return humanId;
  }

  /// Real-time stream of complaints owned by the student.
  /// Uses equality filter `where('userId', isEqualTo: uid)` to comply with Security Rules.
  Stream<List<ComplaintModel>> streamComplaints(String uid) {
    if (!isFirebaseInitialized) {
      return Stream.value(MockDataService.instance.complaints);
    }

    return _complaintsRef
        .where('userId', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ComplaintModel.fromFirestore(doc)).toList();
    });
  }

  /// Combines status history events and follow-up events into a single, deduplicated,
  /// chronologically sorted timeline.
  /// If statusEvents is empty, synthesizes a baseline "Complaint Submitted" event
  /// using the complaint's submittedAt and current status.
  static List<TimelineEvent> combineTimelineEvents({
    required List<TimelineEvent> statusEvents,
    required List<TimelineEvent> followUpEvents,
    required DateTime submittedAt,
    required ComplaintStatus status,
    String? userId,
  }) {
    // 1. Status events or baseline fallback
    List<TimelineEvent> effectiveStatus;
    if (statusEvents.isNotEmpty) {
      effectiveStatus = List<TimelineEvent>.from(statusEvents);
    } else {
      effectiveStatus = [
        TimelineEvent(
          id: 'baseline_submitted',
          title: 'Complaint Submitted',
          description: 'Complaint submitted successfully.',
          timestamp: TimelineEvent.formatDateTime(submittedAt),
          isCompleted: true,
          isActive: status == ComplaintStatus.pending,
          rawTimestamp: submittedAt,
          updatedBy: userId,
        ),
      ];
    }

    // 2. Deduplicate status events by ID / content
    final seenStatus = <String>{};
    final uniqueStatus = <TimelineEvent>[];
    for (final ev in effectiveStatus) {
      final key = ev.id ?? '${ev.title}|${ev.description}|${ev.timestamp}';
      if (seenStatus.add(key)) {
        uniqueStatus.add(ev);
      }
    }

    // 3. Deduplicate follow-up events by ID / content
    final seenFollowUps = <String>{};
    final uniqueFollowUps = <TimelineEvent>[];
    for (final ev in followUpEvents) {
      final key = ev.id ?? '${ev.title}|${ev.description}|${ev.timestamp}';
      if (seenFollowUps.add(key)) {
        uniqueFollowUps.add(ev);
      }
    }

    // 4. Combine and sort chronologically
    final allEvents = [...uniqueStatus, ...uniqueFollowUps];
    allEvents.sort((a, b) {
      if (a.rawTimestamp != null && b.rawTimestamp != null) {
        final cmp = a.rawTimestamp!.compareTo(b.rawTimestamp!);
        if (cmp != 0) return cmp;
      } else if (a.rawTimestamp != null) {
        return -1; // events with known timestamps come before events with pending/null timestamps
      } else if (b.rawTimestamp != null) {
        return 1;
      }
      return a.title.compareTo(b.title);
    });

    return allEvents;
  }

  /// Fetches a single complaint along with its timeline (statusHistory + followUps).
  /// Reactively observes both the parent complaint and its subcollections (statusHistory & followUps),
  /// ensuring real-time timeline updates whenever new status entries or follow-up notes are added.
  Stream<ComplaintModel?> streamComplaintDetails({
    required String complaintDocId,
    required ComplaintModel initialComplaint,
  }) {
    if (!isFirebaseInitialized) {
      return Stream.value(initialComplaint);
    }

    final complaintDoc = _complaintsRef.doc(complaintDocId);
    final statusRef = complaintDoc.collection('statusHistory');
    final followUpRef = complaintDoc.collection('followUps');

    late StreamController<ComplaintModel?> controller;
    StreamSubscription? complaintSub;
    StreamSubscription? statusSub;
    StreamSubscription? followUpSub;

    DocumentSnapshot<Map<String, dynamic>>? latestDoc;

    // Seed from initialComplaint to preserve already-loaded entries while listeners initialize
    final initialFollowUps = initialComplaint.timeline
        .where((e) => e.title == 'Follow-up Added')
        .toList();
    final initialStatus = initialComplaint.timeline
        .where((e) => e.title != 'Follow-up Added')
        .toList();

    List<TimelineEvent> latestStatusEvents = List<TimelineEvent>.from(initialStatus);
    List<TimelineEvent> latestFollowUpEvents = List<TimelineEvent>.from(initialFollowUps);

    bool hasStatusLoaded = false;
    bool hasFollowUpsLoaded = false;
    ComplaintModel? lastEmitted;

    void updateAndEmit() {
      if (controller.isClosed) return;
      if (latestDoc == null) return;
      if (!latestDoc!.exists) {
        if (lastEmitted != null || (hasStatusLoaded && hasFollowUpsLoaded)) {
          lastEmitted = null;
          controller.add(null);
        }
        return;
      }

      // Do NOT emit an incomplete timeline before subcollections have loaded their initial snapshot,
      // UNLESS the complaint already had initial timeline entries.
      if (!hasStatusLoaded || !hasFollowUpsLoaded) {
        if (initialComplaint.timeline.isEmpty) {
          return;
        }
      }

      final data = latestDoc!.data();
      // Ownership validation: verify document userId matches initial complaint userId if available
      if (data != null &&
          initialComplaint.userId != null &&
          data['userId'] != initialComplaint.userId) {
        if (lastEmitted != null) {
          lastEmitted = null;
          controller.add(null);
        }
        return;
      }

      final submittedAtVal = data?['submittedAt'];
      DateTime submittedDate = initialComplaint.submittedAt;
      if (submittedAtVal is Timestamp) {
        submittedDate = submittedAtVal.toDate();
      } else if (submittedAtVal is String) {
        submittedDate = DateTime.tryParse(submittedAtVal) ?? submittedDate;
      }

      final statusStr = data?['status'] as String? ?? 'pending';
      final complaintStatus = ComplaintModel.parseStatus(statusStr);

      final combinedTimeline = combineTimelineEvents(
        statusEvents: latestStatusEvents,
        followUpEvents: latestFollowUpEvents,
        submittedAt: submittedDate,
        status: complaintStatus,
        userId: data?['userId'] as String? ?? initialComplaint.userId,
      );

      final complaint = ComplaintModel.fromFirestore(
        latestDoc!,
        timeline: combinedTimeline,
        fallbackSubmittedAt: initialComplaint.submittedAt,
      );

      // Prevent redundant emissions when model has not changed
      if (lastEmitted == null || lastEmitted != complaint) {
        lastEmitted = complaint;
        controller.add(complaint);
      }
    }

    controller = StreamController<ComplaintModel?>(
      onListen: () {
        complaintSub = complaintDoc.snapshots().listen(
          (docSnap) {
            latestDoc = docSnap;
            updateAndEmit();
          },
          onError: (err) {
            debugPrint('Diagnostic: Error listening to complaint document: $err');
            if (!controller.isClosed) controller.addError(err);
          },
        );

        statusSub = statusRef.snapshots().listen(
          (snap) {
            hasStatusLoaded = true;
            latestStatusEvents = snap.docs.map((d) {
              return TimelineEvent.fromFirestore(d.data(), id: d.id);
            }).toList();
            updateAndEmit();
          },
          onError: (err) {
            debugPrint('Diagnostic: Error listening to statusHistory: $err');
            hasStatusLoaded = true;
            updateAndEmit();
          },
        );

        followUpSub = followUpRef.snapshots().listen(
          (snap) {
            hasFollowUpsLoaded = true;
            latestFollowUpEvents = snap.docs.map((d) {
              return TimelineEvent.fromFollowUpFirestore(d.data(), id: d.id);
            }).toList();
            updateAndEmit();
          },
          onError: (err) {
            debugPrint('Diagnostic: Error listening to followUps: $err');
            hasFollowUpsLoaded = true;
            updateAndEmit();
          },
        );
      },
      onCancel: () async {
        await complaintSub?.cancel();
        await statusSub?.cancel();
        await followUpSub?.cancel();
        complaintSub = null;
        statusSub = null;
        followUpSub = null;
      },
    );

    return controller.stream;
  }

  /// Fetches a complaint by human-readable ID (#CH...) or Firestore document ID.
  /// Validates that the requested document belongs to the authenticated user.
  Future<ComplaintModel?> getComplaintById({
    required String complaintId,
    required String uid,
  }) async {
    if (!isFirebaseInitialized) {
      try {
        return MockDataService.instance.complaints.firstWhere(
          (c) => c.id == complaintId || c.docId == complaintId,
        );
      } catch (_) {
        return null;
      }
    }

    try {
      // 1. Try querying by human id (#CH...)
      final querySnap = await _complaintsRef
          .where('userId', isEqualTo: uid)
          .where('id', isEqualTo: complaintId)
          .limit(1)
          .get();

      if (querySnap.docs.isNotEmpty) {
        return ComplaintModel.fromFirestore(querySnap.docs.first);
      }

      // 2. Try fetching directly by document ID with ownership check
      final docSnap = await _complaintsRef.doc(complaintId).get();
      if (docSnap.exists && docSnap.data()?['userId'] == uid) {
        return ComplaintModel.fromFirestore(docSnap);
      }
    } catch (e) {
      // Log diagnostic detail without exposing sensitive data
      // Do not silently display demo records if Firestore reads fail
    }
    return null;
  }

  /// Appends a follow-up message to an existing complaint.
  Future<void> addFollowUp({
    required String complaintDocId,
    required String uid,
    required String authorName,
    required String description,
  }) async {
    if (!isFirebaseInitialized) {
      MockDataService.instance.addFollowUp(complaintDocId, description);
      return;
    }

    // Ownership check: ensure user owns the target complaint
    final docSnap = await _complaintsRef.doc(complaintDocId).get();
    if (!docSnap.exists || docSnap.data()?['userId'] != uid) {
      throw const FormatException('You do not have permission to add a follow-up to this complaint.');
    }

    final followUpRef =
        _complaintsRef.doc(complaintDocId).collection('followUps').doc();

    await followUpRef.set({
      'userId': uid,
      'authorName': authorName.trim(),
      'description': description.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================================
  // 3. Notifications Management (Read & Update Read-State Only)
  // =========================================================================

  /// Real-time stream of notifications for the authenticated student.
  Stream<List<NotificationModel>> streamNotifications(String uid) {
    if (!isFirebaseInitialized) {
      return Stream.value(MockDataService.instance.notifications);
    }

    return _usersRef
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Updates notifications read-state in batches.
  Future<void> markAllNotificationsRead(String uid) async {
    if (!isFirebaseInitialized) {
      MockDataService.instance.markAllNotificationsRead();
      return;
    }

    final query = await _usersRef
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (query.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'isNew': false,
      });
    }

    await batch.commit();
  }
}
