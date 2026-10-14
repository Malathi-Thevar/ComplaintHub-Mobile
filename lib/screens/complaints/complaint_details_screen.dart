import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/complaint_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_badge.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final ComplaintModel complaint;

  const ComplaintDetailsScreen({
    super.key,
    required this.complaint,
  });

  @override
  State<ComplaintDetailsScreen> createState() =>
      _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  Stream<ComplaintModel?>? _complaintStream;
  String? _subscribedDocId;

  @override
  void initState() {
    super.initState();
    _subscribeToComplaint();
  }

  void _subscribeToComplaint() {
    final authUser = AuthService.instance.currentUser;
    final docId = widget.complaint.effectiveDocId;
    if (authUser != null && FirestoreService.instance.isFirebaseInitialized && docId.isNotEmpty) {
      _subscribedDocId = docId;
      _complaintStream = FirestoreService.instance.streamComplaintDetails(
        complaintDocId: docId,
        initialComplaint: widget.complaint,
      );
    } else {
      _subscribedDocId = null;
      _complaintStream = null;
    }
  }

  @override
  void didUpdateWidget(ComplaintDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.complaint.effectiveDocId != widget.complaint.effectiveDocId ||
        oldWidget.complaint.id != widget.complaint.id) {
      _subscribeToComplaint();
    }
  }

  @override
  void dispose() {
    _complaintStream = null;
    _subscribedDocId = null;
    super.dispose();
  }
  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final hour = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);

    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';

    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '$hour:$minute $period';
  }

  void _showAddFollowUpDialog(BuildContext context) {
    final followUpController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add Follow-up Note',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Provide any additional information or inquiry regarding your complaint.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: followUpController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter follow-up details...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = followUpController.text.trim();

                if (text.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  final user = AuthService.instance.currentUser;
                  final author = MockDataService.instance.currentUser.fullName;

                  if (user != null) {
                    await FirestoreService.instance.addFollowUp(
                      complaintDocId: widget.complaint.effectiveDocId,
                      uid: user.uid,
                      authorName: author,
                      description: text,
                    );
                  } else {
                    MockDataService.instance.addFollowUp(
                      widget.complaint.id,
                      text,
                    );
                  }

                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Follow-up note added successfully',
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(100, 42),
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = AuthService.instance.currentUser;
    final bool isUnauthorized = authUser != null &&
        widget.complaint.userId != null &&
        widget.complaint.userId!.isNotEmpty &&
        widget.complaint.userId != authUser.uid;

    if (isUnauthorized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Complaint Details'),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.danger),
                SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You do not have permission to view or access this complaint.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: MockDataService.instance,
      builder: (context, child) {
        final mockComplaint = MockDataService.instance.complaints.firstWhere(
          (c) => c.id == widget.complaint.id,
          orElse: () => widget.complaint,
        );

        if (authUser != null && FirestoreService.instance.isFirebaseInitialized) {
          if (_complaintStream == null || _subscribedDocId != widget.complaint.effectiveDocId) {
            _subscribeToComplaint();
          }

          final effectiveInitial = widget.complaint.timeline.isNotEmpty
              ? widget.complaint
              : widget.complaint.copyWith(
                  timeline: [
                    TimelineEvent(
                      id: 'baseline_submitted',
                      title: 'Complaint Submitted',
                      description: 'Complaint submitted successfully.',
                      timestamp: _formatDateTime(widget.complaint.submittedAt),
                      isCompleted: true,
                      isActive: widget.complaint.status == ComplaintStatus.pending,
                      rawTimestamp: widget.complaint.submittedAt,
                    ),
                  ],
                );

          return StreamBuilder<ComplaintModel?>(
            stream: _complaintStream,
            initialData: effectiveInitial,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Diagnostic: Error loading complaint details: ${snapshot.error}');
                return Scaffold(
                  backgroundColor: AppColors.background,
                  appBar: AppBar(
                    title: const Text('Complaint Details'),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  body: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                        SizedBox(height: 16),
                        Text(
                          'Unable to Load Complaint',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Could not load complaint details. Please check your connection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final complaint = snapshot.data ?? widget.complaint;
              return _buildScaffold(context, complaint);
            },
          );
        }

        return _buildScaffold(context, mockComplaint);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, ComplaintModel complaint) {
    final effectiveComplaint = complaint.timeline.isNotEmpty
        ? complaint
        : complaint.copyWith(
            timeline: [
              TimelineEvent(
                id: 'baseline_submitted',
                title: 'Complaint Submitted',
                description: 'Complaint submitted successfully.',
                timestamp: _formatDateTime(complaint.submittedAt),
                isCompleted: true,
                isActive: complaint.status == ComplaintStatus.pending,
                rawTimestamp: complaint.submittedAt,
              ),
            ],
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Complaint Details'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share_outlined,
              size: 20,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Complaint ID: ${effectiveComplaint.id} copied to clipboard',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Complaint Summary & Metadata Card
            _buildMetadataCard(effectiveComplaint),
            const SizedBox(height: 16),

            // 2. Complaint Description Card
            _buildDescriptionCard(effectiveComplaint),
            const SizedBox(height: 16),

            // 3. Complaint Timeline Card
            _buildTimelineCard(effectiveComplaint),
            const SizedBox(height: 24),

            // 4. Add Follow-up Action Button
            CustomButton(
              text: 'Add Follow-up',
              isOutlined: true,
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () => _showAddFollowUpDialog(context),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(ComplaintModel complaint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Header Row with ID and Status Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Complaint ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COMPLAINT ID',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        complaint.id,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Status Badge
                Flexible(
                  child: StatusBadge(
                    status: complaint.status,
                  ),
                ),
              ],
            ),
          ),

          // Metadata Table / Grid
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            child: Column(
              children: [
                _buildMetadataRow(
                  'Submitted',
                  _formatDateTime(complaint.submittedAt),
                ),
                const Divider(
                  color: AppColors.divider,
                  height: 20,
                ),
                _buildMetadataRow(
                  'Category',
                  complaint.category,
                ),
                const Divider(
                  color: AppColors.divider,
                  height: 20,
                ),
                _buildMetadataRow(
                  'Concerned Department',
                  complaint.concernedDepartment,
                ),
                const Divider(
                  color: AppColors.divider,
                  height: 20,
                ),
                _buildMetadataRow(
                  'Current Status',
                  complaint.status.label,
                  isStatus: true,
                  status: complaint.status,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(
    String label,
    String value, {
    bool isStatus = false,
    ComplaintStatus? status,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Value / Status
        Expanded(
          flex: 6,
          child: Align(
            alignment: Alignment.centerRight,
            child: isStatus && status != null
                ? StatusBadge(status: status)
                : Text(
                    value,
                    textAlign: TextAlign.right,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard(ComplaintModel complaint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complaint Description',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            complaint.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (complaint.attachmentName != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.attach_file,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      complaint.attachmentName!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineCard(ComplaintModel complaint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complaint Timeline',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          ...complaint.timeline.asMap().entries.map((entry) {
            final idx = entry.key;
            final event = entry.value;
            final isLast =
                idx == complaint.timeline.length - 1;

            return _buildTimelineStep(
              event,
              isLast,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(
    TimelineEvent event,
    bool isLast,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left indicator column with line
          Column(
            children: [
              _buildStepIndicator(event),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: event.isCompleted
                        ? AppColors.accent
                        : AppColors.border,
                  ),
                ),
            ],
          ),

          const SizedBox(width: 14),

          // Right step details
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: event.isCompleted ||
                                    event.isActive
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          event.timestamp,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: event.isCompleted ||
                              event.isActive
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(
    TimelineEvent event,
  ) {
    if (event.isCompleted) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check,
          size: 13,
          color: Colors.white,
        ),
      );
    }

    if (event.isActive) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.accent,
            width: 2,
          ),
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.border,
          width: 2,
        ),
      ),
    );
  }
}