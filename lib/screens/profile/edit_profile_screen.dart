import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _regNoController;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  String? _selectedDepartment;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = MockDataService.instance.currentUser;
    _regNoController = TextEditingController(text: user.registerNumber);
    _nameController = TextEditingController(text: user.fullName);
    _emailController = TextEditingController(text: user.email);
    _selectedDepartment = user.department;
  }

  @override
  void dispose() {
    _regNoController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);

      final user = AuthService.instance.currentUser;
      final dept = _selectedDepartment ?? MockDataService.instance.currentUser.department;
      final name = _nameController.text.trim();

      try {
        if (user != null) {
          await FirestoreService.instance.updateUserProfile(
            uid: user.uid,
            fullName: name,
            department: dept,
            email: _emailController.text.trim(),
          );
        } else {
          MockDataService.instance.updateProfile(
            fullName: name,
            department: dept,
            email: _emailController.text.trim(),
          );
        }

        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profile'),
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
                // Register Number (Read Only)
                CustomTextField(
                  label: 'Register Number',
                  hintText: '',
                  controller: _regNoController,
                  readOnly: true,
                  enabled: false,
                  helperText: 'Register number cannot be changed.',
                ),
                const SizedBox(height: 18),

                // Full Name
                CustomTextField(
                  label: 'Full Name',
                  hintText: 'Enter your full name',
                  controller: _nameController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Department
                CustomTextField(
                  label: 'Department',
                  hintText: 'Enter your department',
                  controller: TextEditingController(text: _selectedDepartment),
                  onChanged: (val) => _selectedDepartment = val,
                ),
                const SizedBox(height: 18),

                // Email Address
                CustomTextField(
                  label: 'Email Address',
                  hintText: 'Enter your email address',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!val.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 36),

                // Save Changes Button
                CustomButton(
                  text: 'Save Changes',
                  isLoading: _isSaving,
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
