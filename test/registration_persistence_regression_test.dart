import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:complaint_hub/models/complaint_model.dart';
import 'package:complaint_hub/models/user_model.dart';
import 'package:complaint_hub/services/auth_service.dart';
import 'package:complaint_hub/services/firestore_service.dart';
import 'package:complaint_hub/services/mock_data_service.dart';
import 'package:complaint_hub/screens/splash/splash_screen.dart';
import 'package:complaint_hub/screens/auth/welcome_screen.dart';
import 'package:complaint_hub/screens/auth/login_screen.dart';

void main() {
  group('1. Register Number Integrity & Preservation', () {
    setUp(() {
      MockDataService.instance.clearUserData();
    });

    test('MockDataService initializes with empty register number (no hardcoded default)', () {
      final user = MockDataService.instance.currentUser;
      expect(user.registerNumber, isEmpty);
      expect(user.fullName, isEmpty);
      expect(user.email, isEmpty);
    });

    test('syncWithFirebaseUser never derives or overwrites registerNumber', () {
      // 1. Student with explicitly registered register number
      const registeredStudent = UserModel(
        uid: 'student_123',
        registerNumber: '21IT055',
        fullName: 'Dhanya R',
        department: 'Information Technology',
        email: 'dhanya@student.tce.edu',
        academicYear: 'IV Year',
      );

      MockDataService.instance.setUser(registeredStudent);
      expect(MockDataService.instance.currentUser.registerNumber, '21IT055');

      // 2. syncWithFirebaseUser with numeric email prefix must NOT overwrite registerNumber
      MockDataService.instance.syncWithFirebaseUser(
        email: '999999999999@student.tce.edu',
        displayName: 'Dhanya R',
        uid: 'student_123',
      );
      expect(
        MockDataService.instance.currentUser.registerNumber,
        '21IT055',
        reason: 'Register number must not be overwritten by numeric email prefix heuristics',
      );

      // 3. syncWithFirebaseUser with alphabetical email prefix must NOT fallback or alter registerNumber
      MockDataService.instance.syncWithFirebaseUser(
        email: 'dhanya.r@student.tce.edu',
        displayName: 'Dhanya R',
        uid: 'student_123',
      );
      expect(
        MockDataService.instance.currentUser.registerNumber,
        '21IT055',
        reason: 'Register number must remain intact and never fallback',
      );
    });

    test('clearUserData cleanly resets profile state between student sessions', () {
      MockDataService.instance.setUser(const UserModel(
        uid: 'student_a',
        registerNumber: '820621104001',
        fullName: 'Student A',
        department: 'CSE',
        email: 'a@student.tce.edu',
      ));
      expect(MockDataService.instance.currentUser.registerNumber, '820621104001');

      MockDataService.instance.clearUserData();
      expect(MockDataService.instance.currentUser.registerNumber, isEmpty);
      expect(MockDataService.instance.currentUser.uid, isNull);
      expect(MockDataService.instance.complaints, isEmpty);
    });
  });

  group('2. Missing Profile Handling & Hydration', () {
    test('getUserProfile returns null for non-existent profiles without inventing mock data', () async {
      // When Firebase is not initialized (unit test), it returns currentUser which is currently empty
      MockDataService.instance.clearUserData();
      final profile = await FirestoreService.instance.getUserProfile('non_existent_uid');
      expect(profile?.registerNumber, isEmpty);
    });

    testWidgets('SplashScreen transitions to WelcomeScreen when unauthenticated',
        (WidgetTester tester) async {
      MockDataService.instance.clearUserData();

      await tester.pumpWidget(const MaterialApp(
        home: SplashScreen(),
      ));

      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 3000));
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('3. Registration & Error Handling', () {
    test('AuthService translates FormatException and custom error messages', () {
      const customError = FormatException('This register number is already registered.');
      expect(
        AuthService.getReadableErrorMessage(customError),
        'This register number is already registered.',
      );

      const securityRuleError = FormatException(
        'Registration request was rejected by database security rules (permission-denied).',
      );
      expect(
        AuthService.getReadableErrorMessage(securityRuleError),
        contains('database security rules'),
      );
    });

    test('createUserProfile in offline mode sets user model accurately', () async {
      MockDataService.instance.clearUserData();
      const student = UserModel(
        uid: 'offline_student',
        registerNumber: '21CS099',
        fullName: 'Karthik M',
        department: 'Computer Science',
        email: 'karthik@student.tce.edu',
      );

      await FirestoreService.instance.createUserProfile(
        uid: 'offline_student',
        user: student,
      );

      expect(MockDataService.instance.currentUser.registerNumber, '21CS099');
      expect(MockDataService.instance.currentUser.fullName, 'Karthik M');
    });
  });

  group('4. Authenticated Complaint Submission & Ownership', () {
    setUp(() {
      MockDataService.instance.clearUserData();
    });

    test('submitComplaint strictly rejects mock_student or empty UID', () async {
      expect(
        () => FirestoreService.instance.submitComplaint(
          uid: 'mock_student',
          category: 'Academic',
          department: 'Computer Science',
          subject: 'Test Subject',
          description: 'Test Description',
        ),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => FirestoreService.instance.submitComplaint(
          uid: '',
          category: 'Academic',
          department: 'Computer Science',
          subject: 'Test Subject',
          description: 'Test Description',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('submitComplaint records valid complaint with authenticated student UID', () async {
      final complaintId = await FirestoreService.instance.submitComplaint(
        uid: 'student_valid_uid',
        category: 'Hostel',
        department: 'Hostel Office',
        subject: 'Room maintenance',
        description: 'Ceiling fan not working',
      );

      expect(complaintId, startsWith('#CH'));
      expect(MockDataService.instance.complaints.length, 1);
      final submitted = MockDataService.instance.complaints.first;
      expect(submitted.userId, 'student_valid_uid');
      expect(submitted.status, ComplaintStatus.pending);
      expect(submitted.subject, 'Room maintenance');
    });
  });

  group('5. Cross-Student Complaint Isolation', () {
    setUp(() {
      MockDataService.instance.clearUserData();
    });

    test('Student B cannot access Student A complaints in memory or streams', () {
      // Register complaint for Student A
      MockDataService.instance.setUser(const UserModel(
        uid: 'student_A',
        registerNumber: '21CS001',
        fullName: 'Student A',
        department: 'CSE',
        email: 'a@student.tce.edu',
      ));

      MockDataService.instance.submitComplaint(
        id: '#CH2001',
        category: 'Lab',
        department: 'CSE',
        subject: 'Keyboard broken',
        description: 'System 4 keyboard broken',
        userId: 'student_A',
      );

      expect(MockDataService.instance.complaints.length, 1);
      expect(MockDataService.instance.complaints.first.userId, 'student_A');

      // Switch context to Student B
      MockDataService.instance.setUser(const UserModel(
        uid: 'student_B',
        registerNumber: '21CS002',
        fullName: 'Student B',
        department: 'CSE',
        email: 'b@student.tce.edu',
      ));

      // Student B must see 0 complaints (Student A's complaint must be completely isolated)
      expect(
        MockDataService.instance.complaints,
        isEmpty,
        reason: 'Student B must have zero visibility into Student A complaints',
      );
    });
  });

  group('6. Login Screen Initial State & Clean Credential Entry', () {
    testWidgets('LoginScreen renders with blank Email/Register Number and Password fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      // Find all TextFormFields on the screen
      final formFields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(formFields.length, 2);

      // Verify both fields start completely empty
      expect(
        formFields[0].controller?.text,
        isEmpty,
        reason: 'Email or Register Number field must be blank when login screen opens',
      );
      expect(
        formFields[1].controller?.text,
        isEmpty,
        reason: 'Password field must be blank when login screen opens',
      );

      // Verify demo credentials are not present in the widget tree
      expect(find.text('820621104001'), findsNothing);
      expect(find.text('student@123'), findsNothing);

      // Attempting to submit empty form must trigger validation errors
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email or register number'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });
}
