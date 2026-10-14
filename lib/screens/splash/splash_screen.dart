import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/mock_data_service.dart';
import '../auth/welcome_screen.dart';
import '../home/main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _navigationTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();

    _navigationTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _checkAuthAndLoadProfile();
      }
    });
  }

  Future<void> _checkAuthAndLoadProfile() async {
    setState(() {
      _errorMessage = null;
    });

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
      return;
    }

    if (FirestoreService.instance.isFirebaseInitialized) {
      // 1. Validate that the cached session is still active in Firebase Authentication
      try {
        await currentUser.reload();
        // Force refresh ID token so Firestore has an up-to-date, authenticated token
        await currentUser.getIdToken(true);
      } on FirebaseAuthException catch (authError) {
        debugPrint(
          'Diagnostic: User session validation encountered FirebaseAuthException: '
          'code=${authError.code}, uid=${currentUser.uid}',
        );
        if (authError.code == 'user-not-found' ||
            authError.code == 'user-disabled' ||
            authError.code == 'invalid-user-token' ||
            authError.code == 'user-token-expired' ||
            authError.code == 'token-expired') {
          // Account was deleted, disabled, or session was revoked in Firebase Auth
          await AuthService.instance.signOut();
          MockDataService.instance.clearUserData();
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            );
          }
          return;
        } else {
          // Network failure or temporary service error: do NOT sign out, show recoverable error
          if (mounted) {
            setState(() {
              _errorMessage =
                  'Authentication check failed: ${AuthService.getReadableErrorMessage(authError)}';
            });
          }
          return;
        }
      } catch (generalError) {
        // Temporary network or socket error: do NOT sign out, show recoverable error
        if (mounted) {
          setState(() {
            _errorMessage =
                'Connection error: ${AuthService.getReadableErrorMessage(generalError)}';
          });
        }
        return;
      }

      // Check current user again after reload
      final activeUser = AuthService.instance.currentUser;
      if (activeUser == null) {
        await AuthService.instance.signOut();
        MockDataService.instance.clearUserData();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          );
        }
        return;
      }

      // 2. Fetch profile from Firestore
      UserModel? profile;
      try {
        profile = await FirestoreService.instance.getUserProfile(activeUser.uid);
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Unable to load profile: ${AuthService.getReadableErrorMessage(e)}';
          });
        }
        return;
      }

      if (profile == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Student profile not found in Firestore. Please sign in again or contact administration.';
          });
        }
        return;
      }

      // Retain the authenticated profile without overwriting through mock synchronization
      MockDataService.instance.setUser(profile);
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  Future<void> _handleSignOut() async {
    await AuthService.instance.signOut();
    MockDataService.instance.clearUserData();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // TCE Emblem / Logo
                Image.asset(
                  AppAssets.tceLogo,
                  width: 130,
                  height: 130,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 28),

                // App Title
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                // Grievance Redressal System
                const Text(
                  'Grievance Redressal System',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 4),

                // College Name
                const Text(
                  AppConstants.collegeFullName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),

                const SizedBox(height: 36),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.statusRejectedBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _handleSignOut,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Sign Out'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _checkAuthAndLoadProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ] else ...[
                  // Segmented / Animated Loading Bar
                  SizedBox(
                    width: 140,
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progressController.value,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.accent,
                            ),
                            minHeight: 4,
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}