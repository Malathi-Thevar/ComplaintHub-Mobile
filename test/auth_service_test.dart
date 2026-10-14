import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:complaint_hub/services/auth_service.dart';

void main() {
  group('AuthService TCE Domain Validation', () {
    test('validates student TCE email', () {
      expect(AuthService.isValidTceEmail('arun@student.tce.edu'), isTrue);
      expect(AuthService.isValidTceEmail('820621104001@student.tce.edu'), isTrue);
      expect(AuthService.isValidTceEmail('  DHANYA@STUDENT.TCE.EDU  '), isTrue);
    });

    test('validates college TCE email', () {
      expect(AuthService.isValidTceEmail('grievance@tce.edu'), isTrue);
      expect(AuthService.isValidTceEmail('student@tce.edu'), isTrue);
    });

    test('rejects non-TCE emails', () {
      expect(AuthService.isValidTceEmail('arun@gmail.com'), isFalse);
      expect(AuthService.isValidTceEmail('student@yahoo.com'), isFalse);
      expect(AuthService.isValidTceEmail(''), isFalse);
      expect(AuthService.isValidTceEmail('@student.tce.edu'), isFalse);
      expect(AuthService.isValidTceEmail('@tce.edu'), isFalse);
      expect(AuthService.isValidTceEmail('fake@notstudent.tce.edu'), isFalse);
    });

    test('normalizes register numbers without domain to student.tce.edu', () {
      expect(
        AuthService.normalizeLoginIdentifier('820621104001'),
        '820621104001@student.tce.edu',
      );
      expect(
        AuthService.normalizeLoginIdentifier('arunkumar'),
        'arunkumar@student.tce.edu',
      );
    });

    test('preserves already full emails during normalization', () {
      expect(
        AuthService.normalizeLoginIdentifier('arun@student.tce.edu'),
        'arun@student.tce.edu',
      );
      expect(
        AuthService.normalizeLoginIdentifier('student@tce.edu'),
        'student@tce.edu',
      );
    });
  });

  group('AuthService Readable Error Messages', () {
    test('translates standard FirebaseAuthException codes', () {
      expect(
        AuthService.getReadableErrorMessage(
          FirebaseAuthException(code: 'user-not-found'),
        ),
        contains('No student account found'),
      );

      expect(
        AuthService.getReadableErrorMessage(
          FirebaseAuthException(code: 'wrong-password'),
        ),
        contains('Incorrect password'),
      );

      expect(
        AuthService.getReadableErrorMessage(
          FirebaseAuthException(code: 'invalid-credential'),
        ),
        contains('Invalid credentials'),
      );

      expect(
        AuthService.getReadableErrorMessage(
          FirebaseAuthException(code: 'email-already-in-use'),
        ),
        contains('An account already exists'),
      );

      expect(
        AuthService.getReadableErrorMessage(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        contains('Network error'),
      );
    });

    test('handles FormatException gracefully', () {
      expect(
        AuthService.getReadableErrorMessage(
          const FormatException('Custom validation message'),
        ),
        'Custom validation message',
      );
    });
  });
}
