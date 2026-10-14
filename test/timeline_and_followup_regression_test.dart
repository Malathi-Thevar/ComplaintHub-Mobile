import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:complaint_hub/models/complaint_model.dart';
import 'package:complaint_hub/models/user_model.dart';
import 'package:complaint_hub/services/firestore_service.dart';
import 'package:complaint_hub/services/mock_data_service.dart';
import 'package:complaint_hub/screens/complaints/complaint_details_screen.dart';

void main() {
  setUp(() {
    MockDataService.instance.clearUserData();
  });

  group('1. Timeline Baseline & Empty Status History Fallback', () {
    test('Constructs baseline "Complaint Submitted" event when timeline and statusHistory are empty', () {
      final submittedDate = DateTime(2026, 10, 12, 14, 30);
      final complaint = ComplaintModel(
        id: '#CH284035',
        category: 'Academic',
        concernedDepartment: 'Computer Science',
        subject: 'Lab Systems Down',
        description: 'Systems 1 to 5 in Lab 2 are not booting.',
        status: ComplaintStatus.pending,
        submittedAt: submittedDate,
        timeline: const [],
      );

      // Verify baseline event formatting
      final formatted = TimelineEvent.formatDateTime(submittedDate);
      expect(formatted, contains('12 Oct 2026'));
      expect(formatted, contains('2:30 PM'));

      // Deserialization with empty status history should construct baseline event
      expect(complaint.timeline, isEmpty);
    });

    testWidgets('ComplaintDetailsScreen renders baseline submission event even when complaint has empty timeline',
        (WidgetTester tester) async {
      final submittedDate = DateTime(2026, 10, 12, 10, 15);
      final complaint = ComplaintModel(
        id: '#CH284035',
        category: 'Academic',
        concernedDepartment: 'Computer Science',
        subject: 'Lab Manuals',
        description: 'Manuals needed.',
        status: ComplaintStatus.pending,
        submittedAt: submittedDate,
        timeline: const [],
      );

      await tester.pumpWidget(MaterialApp(
        home: ComplaintDetailsScreen(complaint: complaint),
      ));

      // The baseline event must be displayed immediately
      expect(find.text('Complaint Timeline'), findsOneWidget);
      expect(find.text('Complaint Submitted'), findsOneWidget);
      expect(find.text('Complaint submitted successfully.'), findsOneWidget);
      expect(find.textContaining('10:15 AM'), findsNWidgets(2));
    });
  });

  group('2. Missing Timestamps & Graceful Degradation', () {
    test('TimelineEvent.fromFollowUpFirestore handles missing or null timestamp gracefully without dropping event', () {
      final docWithoutTimestamp = {
        'userId': 'student_123',
        'authorName': 'Arun Kumar S',
        'description': 'Follow-up note without server timestamp yet.',
      };

      final event = TimelineEvent.fromFollowUpFirestore(docWithoutTimestamp);
      expect(event.title, 'Follow-up Added');
      expect(event.description, 'Follow-up note without server timestamp yet.');
      expect(event.timestamp, 'Just now');
      expect(event.rawTimestamp, isNull);
    });

    test('TimelineEvent.fromFollowUpFirestore parses String ISO timestamp as fallback', () {
      final docWithStringTimestamp = {
        'userId': 'student_123',
        'authorName': 'Arun Kumar S',
        'description': 'Follow-up with ISO string timestamp.',
        'timestamp': '2026-10-12T16:45:00.000',
      };

      final event = TimelineEvent.fromFollowUpFirestore(docWithStringTimestamp);
      expect(event.description, 'Follow-up with ISO string timestamp.');
      expect(event.timestamp, contains('12 Oct 2026'));
      expect(event.timestamp, contains('4:45 PM'));
      expect(event.rawTimestamp, isNotNull);
    });
  });

  group('3. Deserialization Field Compatibility (description vs message)', () {
    test('TimelineEvent.fromFollowUpFirestore reads canonical "description" field', () {
      final docWithDescription = {
        'userId': 'student_123',
        'authorName': 'Dhanya R',
        'description': 'Please expedite this repair.',
      };

      final event = TimelineEvent.fromFollowUpFirestore(docWithDescription);
      expect(event.description, 'Please expedite this repair.');
    });

    test('TimelineEvent.fromFollowUpFirestore supports legacy or dashboard "message" field', () {
      final docWithMessage = {
        'userId': 'student_123',
        'authorName': 'Staff Member',
        'message': 'Component has been ordered from vendor.',
      };

      final event = TimelineEvent.fromFollowUpFirestore(docWithMessage);
      expect(event.description, 'Component has been ordered from vendor.');
    });

    test('TimelineEvent.fromFirestore supports both "description" and "message"', () {
      final doc = {
        'title': 'Staff Remark',
        'message': 'Verified on site.',
      };

      final event = TimelineEvent.fromFirestore(doc);
      expect(event.title, 'Staff Remark');
      expect(event.description, 'Verified on site.');
    });
  });

  group('4. Follow-up Addition & Timeline Visibility in ComplaintDetailsScreen', () {
    testWidgets('Newly submitted follow-up appears on screen and persists upon reopening',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      MockDataService.instance.setUser(const UserModel(
        uid: 'student_tester',
        registerNumber: '820621104001',
        fullName: 'Arun Kumar S',
        department: 'Computer Science',
        email: 'arun@student.tce.edu',
      ));

      MockDataService.instance.submitComplaint(
        id: '#CH284035',
        category: 'Lab',
        department: 'Computer Science',
        subject: 'Lab Systems Down',
        description: 'Systems 1 to 5 in Lab 2 are not booting.',
        userId: 'student_tester',
      );

      final submittedComplaint = MockDataService.instance.complaints.first;
      expect(submittedComplaint.id, '#CH284035');

      // 1. Open Complaint Details screen
      await tester.pumpWidget(MaterialApp(
        home: ComplaintDetailsScreen(complaint: submittedComplaint),
      ));

      expect(find.text('Complaint Timeline'), findsOneWidget);
      expect(find.text('Complaint Submitted'), findsOneWidget);

      // 2. Tap Add Follow-up and submit note
      final addFollowUpButton = find.text('Add Follow-up');
      await tester.ensureVisible(addFollowUpButton);
      await tester.tap(addFollowUpButton);
      await tester.pumpAndSettle();

      expect(find.text('Add Follow-up Note'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Lab technician arrived and inspected.');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // 3. Verify newly submitted follow-up appears immediately without leaving screen
      expect(find.text('Follow-up Added'), findsOneWidget);
      expect(find.text('Lab technician arrived and inspected.'), findsOneWidget);

      // 4. Reopen complaint (simulate navigating away and opening anew)
      final reloadedComplaint = MockDataService.instance.complaints.first;
      await tester.pumpWidget(MaterialApp(
        home: ComplaintDetailsScreen(complaint: reloadedComplaint),
      ));

      // 5. Follow-ups and status history remain visible after reopening
      expect(find.text('Complaint Timeline'), findsOneWidget);
      expect(find.text('Complaint Submitted'), findsOneWidget);
      expect(find.text('Follow-up Added'), findsOneWidget);
      expect(find.text('Lab technician arrived and inspected.'), findsOneWidget);
    });
  });

  group('5. Anti-Flicker & Stream Combination Stability', () {
    test('combineTimelineEvents preserves follow-ups, synthesizes baseline, and sorts chronologically', () {
      final submittedAt = DateTime(2026, 10, 12, 9, 0);
      final followUpTime1 = DateTime(2026, 10, 12, 11, 30);
      final followUpTime2 = DateTime(2026, 10, 12, 14, 15);

      final followUps = [
        TimelineEvent(
          id: 'fu_2',
          title: 'Follow-up Added',
          description: 'Second follow-up note.',
          timestamp: TimelineEvent.formatDateTime(followUpTime2),
          isCompleted: true,
          rawTimestamp: followUpTime2,
        ),
        TimelineEvent(
          id: 'fu_1',
          title: 'Follow-up Added',
          description: 'First follow-up note.',
          timestamp: TimelineEvent.formatDateTime(followUpTime1),
          isCompleted: true,
          rawTimestamp: followUpTime1,
        ),
      ];

      final combined = FirestoreService.combineTimelineEvents(
        statusEvents: const [],
        followUpEvents: followUps,
        submittedAt: submittedAt,
        status: ComplaintStatus.pending,
        userId: 'student_123',
      );

      expect(combined.length, 3);
      expect(combined[0].title, 'Complaint Submitted');
      expect(combined[1].description, 'First follow-up note.');
      expect(combined[2].description, 'Second follow-up note.');
    });

    test('combineTimelineEvents deduplicates events with identical IDs or content', () {
      final submittedAt = DateTime(2026, 10, 12, 9, 0);
      final followUpTime = DateTime(2026, 10, 12, 11, 30);

      final duplicateFollowUps = [
        TimelineEvent(
          id: 'fu_1',
          title: 'Follow-up Added',
          description: 'Same follow-up note.',
          timestamp: TimelineEvent.formatDateTime(followUpTime),
          isCompleted: true,
          rawTimestamp: followUpTime,
        ),
        TimelineEvent(
          id: 'fu_1',
          title: 'Follow-up Added',
          description: 'Same follow-up note.',
          timestamp: TimelineEvent.formatDateTime(followUpTime),
          isCompleted: true,
          rawTimestamp: followUpTime,
        ),
      ];

      final combined = FirestoreService.combineTimelineEvents(
        statusEvents: const [],
        followUpEvents: duplicateFollowUps,
        submittedAt: submittedAt,
        status: ComplaintStatus.pending,
      );

      expect(combined.length, 2); // 1 baseline + 1 deduplicated follow-up
      expect(combined.where((e) => e.title == 'Follow-up Added').length, 1);
    });

    test('combineTimelineEvents keeps pending-timestamp follow-ups at the end without dropping them', () {
      final submittedAt = DateTime(2026, 10, 12, 9, 0);
      final resolvedFollowUp = TimelineEvent(
        id: 'fu_1',
        title: 'Follow-up Added',
        description: 'Earlier follow-up.',
        timestamp: TimelineEvent.formatDateTime(DateTime(2026, 10, 12, 10, 0)),
        isCompleted: true,
        rawTimestamp: DateTime(2026, 10, 12, 10, 0),
      );
      final pendingFollowUp = TimelineEvent.fromFollowUpFirestore(
        {'description': 'Just submitted follow-up with pending server timestamp.'},
        id: 'fu_2',
      );

      final combined = FirestoreService.combineTimelineEvents(
        statusEvents: const [],
        followUpEvents: [pendingFollowUp, resolvedFollowUp],
        submittedAt: submittedAt,
        status: ComplaintStatus.pending,
      );

      expect(combined.length, 3);
      expect(combined[0].title, 'Complaint Submitted');
      expect(combined[1].description, 'Earlier follow-up.');
      expect(combined[2].description, 'Just submitted follow-up with pending server timestamp.');
      expect(combined[2].timestamp, 'Just now');
    });

    test('ComplaintModel and TimelineEvent equality prevents redundant emissions', () {
      final dt = DateTime(2026, 10, 12, 10, 0);
      final ev1 = TimelineEvent(
        id: 'fu_1',
        title: 'Follow-up Added',
        description: 'Note 1',
        timestamp: '12 Oct 2026, 10:00 AM',
        isCompleted: true,
        rawTimestamp: dt,
      );
      final ev2 = TimelineEvent(
        id: 'fu_1',
        title: 'Follow-up Added',
        description: 'Note 1',
        timestamp: '12 Oct 2026, 10:00 AM',
        isCompleted: true,
        rawTimestamp: dt,
      );

      expect(ev1, equals(ev2));
      expect(ev1.hashCode, equals(ev2.hashCode));

      final c1 = ComplaintModel(
        id: '#CH284035',
        docId: 'doc_1',
        userId: 'u1',
        category: 'Lab',
        concernedDepartment: 'CSE',
        subject: 'Sub',
        description: 'Desc',
        status: ComplaintStatus.pending,
        submittedAt: dt,
        timeline: [ev1],
      );
      final c2 = ComplaintModel(
        id: '#CH284035',
        docId: 'doc_1',
        userId: 'u1',
        category: 'Lab',
        concernedDepartment: 'CSE',
        subject: 'Sub',
        description: 'Desc',
        status: ComplaintStatus.pending,
        submittedAt: dt,
        timeline: [ev2],
      );

      expect(c1, equals(c2));
    });

    testWidgets('Follow-up notes do not disappear or flicker across repeated widget rebuilds',
        (WidgetTester tester) async {
      final submittedAt = DateTime(2026, 10, 12, 9, 0);
      final followUpAt = DateTime(2026, 10, 12, 11, 0);

      final complaintWithFollowUp = ComplaintModel(
        id: '#CH284035',
        category: 'Academic',
        concernedDepartment: 'Computer Science',
        subject: 'Projector Issue',
        description: 'HDMI port not working.',
        status: ComplaintStatus.pending,
        submittedAt: submittedAt,
        timeline: [
          TimelineEvent(
            id: 'baseline_submitted',
            title: 'Complaint Submitted',
            description: 'Complaint submitted successfully.',
            timestamp: TimelineEvent.formatDateTime(submittedAt),
            isCompleted: true,
            isActive: true,
            rawTimestamp: submittedAt,
          ),
          TimelineEvent(
            id: 'fu_1',
            title: 'Follow-up Added',
            description: 'Checked with department technician.',
            timestamp: TimelineEvent.formatDateTime(followUpAt),
            isCompleted: true,
            rawTimestamp: followUpAt,
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: ComplaintDetailsScreen(complaint: complaintWithFollowUp),
      ));

      // Verify initial render shows both baseline and follow-up
      expect(find.text('Complaint Submitted'), findsOneWidget);
      expect(find.text('Follow-up Added'), findsOneWidget);
      expect(find.text('Checked with department technician.'), findsOneWidget);

      // Trigger multiple rebuilds and frame pumps
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Complaint Submitted'), findsOneWidget);
        expect(find.text('Follow-up Added'), findsOneWidget);
        expect(find.text('Checked with department technician.'), findsOneWidget);
      }
    });
  });
}

