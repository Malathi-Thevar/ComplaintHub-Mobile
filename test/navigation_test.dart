import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:complaint_hub/main.dart';
import 'package:complaint_hub/screens/auth/welcome_screen.dart';
import 'package:complaint_hub/screens/auth/login_screen.dart';
import 'package:complaint_hub/screens/auth/register_screen.dart';
import 'package:complaint_hub/screens/auth/forgot_password_screen.dart';
import 'package:complaint_hub/screens/home/main_navigation_screen.dart';
import 'package:complaint_hub/screens/complaints/submit_complaint_screen.dart';
import 'package:complaint_hub/screens/complaints/complaint_details_screen.dart';
import 'package:complaint_hub/screens/profile/edit_profile_screen.dart';
import 'package:complaint_hub/screens/profile/change_password_screen.dart';
import 'package:complaint_hub/screens/profile/help_support_screen.dart';
import 'package:complaint_hub/screens/profile/about_screen.dart';
import 'package:complaint_hub/screens/profile/profile_screen.dart';
import 'package:complaint_hub/models/user_model.dart';
import 'package:complaint_hub/services/mock_data_service.dart';
import 'package:complaint_hub/widgets/logout_bottom_sheet.dart';

void main() {
  testWidgets('Comprehensive ComplaintHub Navigation and Interaction Test',
      (WidgetTester tester) async {
    // Configure realistic phone dimensions (e.g., Samsung Galaxy A06: 720x1600)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Launch App (Splash Screen)
    await tester.pumpWidget(const ComplaintHubApp());
    expect(find.text('ComplaintHub'), findsOneWidget);
    expect(find.text('Grievance Redressal System'), findsOneWidget);

    // Let Splash timer complete and transition to Welcome Screen
    await tester.pumpAndSettle(const Duration(milliseconds: 3000));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Welcome to\nComplaintHub'), findsOneWidget);

    // 2. Welcome -> Login Screen
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Student Login'), findsOneWidget);

    // Verify fields are blank when login screen opens
    final initialLoginFields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(initialLoginFields[0].controller?.text, isEmpty);
    expect(initialLoginFields[1].controller?.text, isEmpty);

    // 3. Login -> Forgot Password Screen
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('Reset Password'), findsOneWidget);

    // Fill Forgot Password & Send
    await tester.enterText(find.byType(TextFormField), 'student@tce.edu');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    expect(find.text('Password Reset Email Sent'), findsOneWidget);

    // Back to Login
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // 4. Login -> Register Screen
    await tester.tap(find.text('Register here'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Create Your Account'), findsOneWidget);

    // Register -> back to Login
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // Verify fields remain blank on returning to Login Screen
    final returnLoginFields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(returnLoginFields[0].controller?.text, isEmpty);
    expect(returnLoginFields[1].controller?.text, isEmpty);

    // 5. Perform Login -> Dashboard (Main Navigation Screen)
    MockDataService.instance.setUser(const UserModel(
      registerNumber: '820621104001',
      fullName: 'Arun Kumar S',
      department: 'Computer Science',
      email: 'arun@student.tce.edu',
      academicYear: 'IV Year',
    ));
    final loginFields = find.byType(TextFormField);
    await tester.enterText(loginFields.at(0), '820621104001');
    await tester.enterText(loginFields.at(1), 'student@123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle(const Duration(milliseconds: 1000));
    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Arun Kumar S'), findsOneWidget);

    // 6. Home: Quick Action -> Submit Complaint
    await tester.tap(find.text('Submit Complaint'));
    await tester.pumpAndSettle();
    expect(find.byType(SubmitComplaintScreen), findsOneWidget);

    // Enter subject & description
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'Lab Manuals Not Available');
    await tester.enterText(textFields.at(1), 'Semester lab manuals are pending print.');

    // Select category dropdown
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Academic').last);
    await tester.pumpAndSettle();

    // Select department dropdown
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();

    // Submit complaint via bottom button
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Submit Complaint'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Complaint'));
    await tester.pumpAndSettle(const Duration(milliseconds: 1000));
    expect(find.text('Complaint Submitted'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(MainNavigationScreen), findsOneWidget);

    // 7. Switch to Complaints Tab (Index 1)
    await tester.tap(find.byIcon(Icons.assignment_outlined));
    await tester.pumpAndSettle();
    expect(find.text('My Complaints'), findsOneWidget);

    // Filter by 'Pending'
    await tester.tap(find.textContaining('Pending').first);
    await tester.pumpAndSettle();

    // Tap on the submitted complaint to open ComplaintDetailsScreen
    await tester.tap(find.text('Lab Manuals Not Available'));
    await tester.pumpAndSettle();
    expect(find.byType(ComplaintDetailsScreen), findsOneWidget);
    expect(find.text('Complaint Timeline'), findsOneWidget);

    // Test Add Follow-up dialog
    await tester.tap(find.text('Add Follow-up'));
    await tester.pumpAndSettle();
    expect(find.text('Add Follow-up Note'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Any update on the manuals?');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Follow-up Added'), findsOneWidget);

    // Back to Complaints list
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    // 8. Switch to Alerts Tab (Index 2)
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);

    // Tap "Mark All Read"
    if (find.text('Mark All Read').evaluate().isNotEmpty) {
      await tester.tap(find.text('Mark All Read'));
      await tester.pumpAndSettle();
    }

    // 9. Switch to Profile Tab (Index 3)
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);

    // Profile -> Edit Profile
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // Profile -> Change Password
    await tester.tap(find.text('Change Password'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    // Profile -> Help & Support
    await tester.tap(find.text('Help & Support'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpSupportScreen), findsOneWidget);
    // Expand an FAQ
    await tester.tap(find.text('How do I submit a complaint?'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    // Profile -> About ComplaintHub
    await tester.tap(find.text('About ComplaintHub'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.textContaining('Malathi P'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    // 10. Logout Confirmation Bottom Sheet
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(find.byType(LogoutBottomSheet), findsOneWidget);
    expect(find.text('Are you sure you want to logout of ComplaintHub?'),
        findsOneWidget);

    // Confirm Logout
    await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
