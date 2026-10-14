import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;

  AuthService._internal();

  static const String tceStudentDomain = '@student.tce.edu';
  static const String tceCollegeDomain = '@tce.edu';

  /// Validates whether the given string is a valid TCE student/college email.
  static bool isValidTceEmail(String email) {
    final trimmed = email.trim().toLowerCase();
    return (trimmed.endsWith(tceStudentDomain) && trimmed.length > tceStudentDomain.length) ||
        (trimmed.endsWith(tceCollegeDomain) && trimmed.length > tceCollegeDomain.length);
  }

  /// Normalizes login input: if user entered a register number or username
  /// without a domain, appends `@student.tce.edu`.
  static String normalizeLoginIdentifier(String identifier) {
    final trimmed = identifier.trim().toLowerCase();
    if (!trimmed.contains('@')) {
      return '$trimmed$tceStudentDomain';
    }
    return trimmed;
  }

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  User? get currentUser =>
      isFirebaseInitialized ? FirebaseAuth.instance.currentUser : null;

  Stream<User?> get authStateChanges => isFirebaseInitialized
      ? FirebaseAuth.instance.authStateChanges()
      : Stream.value(null);

  /// Registers a new student account with Firebase Authentication.
  Future<UserCredential?> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!isValidTceEmail(normalizedEmail)) {
      throw const FormatException(
        'Registration is restricted to official TCE student emails (@student.tce.edu).',
      );
    }

    if (!isFirebaseInitialized) {
      // In test or uninitialized environments, return null safely.
      return null;
    }

    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    if (fullName.trim().isNotEmpty) {
      try {
        await credential.user?.updateDisplayName(fullName.trim());
      } catch (_) {
        // Non-fatal if display name update fails
      }
    }

    return credential;
  }

  /// Authenticates an existing student account with Firebase Authentication.
  Future<UserCredential?> login({
    required String identifier,
    required String password,
  }) async {
    final email = normalizeLoginIdentifier(identifier);

    if (!isValidTceEmail(email)) {
      throw const FormatException(
        'Please enter a valid TCE student email (@student.tce.edu) or register number.',
      );
    }

    if (!isFirebaseInitialized) {
      // In test or uninitialized environments, return null safely.
      return null;
    }

    return await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sends a password reset email via Firebase Authentication.
  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (!isValidTceEmail(normalizedEmail)) {
      throw const FormatException(
        'Please enter a valid registered TCE student email (@student.tce.edu).',
      );
    }

    if (!isFirebaseInitialized) {
      return;
    }

    await FirebaseAuth.instance.sendPasswordResetEmail(email: normalizedEmail);
  }

  /// Signs out the current Firebase user.
  Future<void> signOut() async {
    if (isFirebaseInitialized) {
      await FirebaseAuth.instance.signOut();
    }
  }

  /// Converts Firebase exceptions into user-friendly error messages.
  static String getReadableErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No student account found with this email. Please register first.';
        case 'wrong-password':
          return 'Incorrect password. Please verify and try again.';
        case 'invalid-credential':
          return 'Invalid credentials. Please verify your student email and password.';
        case 'email-already-in-use':
          return 'An account already exists with this student email. Please log in.';
        case 'invalid-email':
          return 'The email address format is invalid.';
        case 'weak-password':
          return 'The password is too weak. Please use at least 6 characters.';
        case 'user-disabled':
          return 'This student account has been disabled. Please contact the administrator.';
        case 'too-many-requests':
          return 'Too many unsuccessful attempts. Please wait a moment and try again.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'operation-not-allowed':
          return 'Email/Password sign-in is not enabled. Please contact support.';
        default:
          return error.message ??
              'Authentication failed (${error.code}). Please try again.';
      }
    } else if (error is FormatException) {
      return error.message;
    }
    return error?.toString() ??
        'An unexpected error occurred. Please try again.';
  }
}
