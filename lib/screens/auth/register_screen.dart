import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../home/main_navigation_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _regNoController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedDepartment;
  bool _isLoading = false;

  @override
  void dispose() {
    _regNoController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_isLoading) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your department')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final regNo = _regNoController.text.trim();
      final fullName = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      final credential = await AuthService.instance.register(
        email: email,
        password: password,
        fullName: fullName,
      );

      final studentUser = UserModel(
        uid: credential?.user?.uid,
        registerNumber: regNo,
        fullName: fullName,
        department: _selectedDepartment!,
        email: credential?.user?.email ?? email,
        academicYear: 'IV Year',
      );

      // Create student profile in Cloud Firestore (with unique register number lock)
      if (credential?.user != null) {
        try {
          await FirestoreService.instance.createUserProfile(
            uid: credential!.user!.uid,
            user: studentUser,
          );
        } catch (profileError) {
          // Rollback: delete the newly created auth account and sign out so no orphan session remains
          bool rollbackSuccess = false;
          Object? rollbackFailure;
          try {
            await credential?.user?.delete();
            rollbackSuccess = true;
          } catch (deleteError) {
            rollbackFailure = deleteError;
            try {
              await AuthService.instance.signOut();
            } catch (_) {}
          }

          if (!rollbackSuccess && rollbackFailure != null) {
            throw FormatException(
              'Profile registration failed: ${AuthService.getReadableErrorMessage(profileError)}. Furthermore, account cleanup failed: ${AuthService.getReadableErrorMessage(rollbackFailure)}. Please contact administration.',
            );
          }
          rethrow;
        }
      } else {
        // Fallback for test / offline state
        MockDataService.instance.setUser(studentUser);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errorMessage = AuthService.getReadableErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                const Text(
                  'Create Your Account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Fill in your details to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Register Number
                CustomTextField(
                  label: 'Register Number',
                  hintText: 'e.g. 820621104001',
                  controller: _regNoController,
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your register number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Full Name
                CustomTextField(
                  label: 'Full Name',
                  hintText: 'e.g. Arun Kumar',
                  controller: _nameController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Department Dropdown
                const Text(
                  'Department',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDepartment,
                  hint: const Text(
                    'Select your department',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: AppConstants.departments.map((dept) {
                    return DropdownMenuItem<String>(
                      value: dept,
                      child: Text(
                        dept,
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedDepartment = val);
                  },
                ),
                const SizedBox(height: 16),

                // Email
                CustomTextField(
                  label: 'Email',
                  hintText: 'e.g. arun@student.tce.edu',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your student email';
                    }
                    final trimmed = val.trim().toLowerCase();
                    if (!trimmed.endsWith('@student.tce.edu') ||
                        trimmed == '@student.tce.edu') {
                      return 'Email must end with @student.tce.edu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                CustomTextField(
                  label: 'Password',
                  hintText: 'Create a password',
                  controller: _passwordController,
                  isPassword: true,
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password
                CustomTextField(
                  label: 'Confirm Password',
                  hintText: 'Repeat your password',
                  controller: _confirmPasswordController,
                  isPassword: true,
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Create Account Button
                CustomButton(
                  text: 'Create Account',
                  isLoading: _isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 20),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already registered? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
