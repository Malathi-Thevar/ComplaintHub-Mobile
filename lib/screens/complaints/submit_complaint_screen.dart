import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _selectedDepartment;
  String? _attachedFileName;
  bool _isSubmitting = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showFileAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attach Supporting File',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Choose Photo / Screenshot
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(
                      Icons.photo_library_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                  title: const Text('Choose Photo / Screenshot'),
                  subtitle: const Text('PNG, JPG up to 5MB'),
                  onTap: () async {
                    Navigator.pop(ctx);

                    try {
                      final XFile? image = await _imagePicker.pickImage(
                        source: ImageSource.gallery,
                      );

                      if (image != null && mounted) {
                        setState(() {
                          _attachedFileName = image.name;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Unable to select the image'),
                          ),
                        );
                      }
                    }
                  },
                ),

                // Choose PDF
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(
                      Icons.description_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                  title: const Text('Choose Document (PDF)'),
                  subtitle: const Text('PDF up to 10MB'),
                  onTap: () async {
                    Navigator.pop(ctx);

                    try {
                      final FilePickerResult? result =
                          await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );

                      if (result != null &&
                          result.files.isNotEmpty &&
                          mounted) {
                        setState(() {
                          _attachedFileName = result.files.single.name;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Unable to select the PDF'),
                          ),
                        );
                      }
                    }
                  },
                ),

                // Take a Photo
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                  title: const Text('Take a Photo'),
                  onTap: () async {
                    Navigator.pop(ctx);

                    try {
                      final XFile? image = await _imagePicker.pickImage(
                        source: ImageSource.camera,
                      );

                      if (image != null && mounted) {
                        setState(() {
                          _attachedFileName = image.name;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Unable to take the photo'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a complaint category')),
        );
        return;
      }
      if (_selectedDepartment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select the concerned department')),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      final user = AuthService.instance.currentUser;
      if (FirestoreService.instance.isFirebaseInitialized && (user == null || user.uid.isEmpty)) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be signed in to submit a complaint.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final uid = user?.uid ?? (MockDataService.instance.currentUser.uid?.isNotEmpty == true
          ? MockDataService.instance.currentUser.uid!
          : 'test_student');

      try {
        await FirestoreService.instance.submitComplaint(
          uid: uid,
          category: _selectedCategory!,
          department: _selectedDepartment!,
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          attachmentName: _attachedFileName,
        );

        if (mounted) {
          setState(() => _isSubmitting = false);

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.statusResolvedBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.statusResolved,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Complaint Submitted',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your grievance has been forwarded to the department for review. You can track progress under My Complaints.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit complaint: $e'),
              backgroundColor: AppColors.danger,
            ),
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
        title: const Text('Submit Complaint'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bannerInfoBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bannerInfoBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(
                        Icons.shield_outlined,
                        size: 20,
                        color: AppColors.accent,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'All complaints are confidential and handled by the respective department authority.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E40AF),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Category Dropdown
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  isExpanded: true,
                  hint: const Text(
                    'Select complaint category',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: AppConstants.complaintCategories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
                const SizedBox(height: 18),

                // Concerned Department Dropdown
                const Text(
                  'Concerned Department',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDepartment,
                  isExpanded: true,
                  hint: const Text(
                    'Select department',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: AppConstants.concernedOffices.map((dept) {
                    return DropdownMenuItem(
                      value: dept,
                      child: Text(
                        dept,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedDepartment = val),
                ),
                const SizedBox(height: 18),

                // Subject Field
                CustomTextField(
                  label: 'Subject',
                  hintText: 'Brief subject of the complaint',
                  controller: _subjectController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a subject';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Description Field
                CustomTextField(
                  label: 'Description',
                  hintText: 'Describe your complaint in detail...',
                  controller: _descriptionController,
                  maxLines: 5,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a description of the issue';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Attach Supporting File
                const Text(
                  'Supporting Documents',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _showFileAttachmentOptions,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _attachedFileName != null ? AppColors.accent : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _attachedFileName != null
                              ? Icons.attachment_rounded
                              : Icons.attach_file_rounded,
                          size: 20,
                          color: _attachedFileName != null
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _attachedFileName ?? 'Attach supporting file (optional)',
                            style: TextStyle(
                              fontSize: 14,
                              color: _attachedFileName != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: _attachedFileName != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_attachedFileName != null)
                          GestureDetector(
                            onTap: () {
                              setState(() => _attachedFileName = null);
                            },
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Complaint Button
                CustomButton(
                  text: 'Submit Complaint',
                  isLoading: _isSubmitting,
                  onPressed: _handleSubmit,
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
