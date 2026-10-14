import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/complaint_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/complaint_card.dart';
import '../complaints/complaint_details_screen.dart';
import '../complaints/submit_complaint_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onNavigateToTab;

  const HomeScreen({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final authUser = AuthService.instance.currentUser;

    final userStream = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
        ? FirestoreService.instance.streamUserProfile(authUser.uid)
        : Stream.value(MockDataService.instance.currentUser);

    final notificationsStream = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
        ? FirestoreService.instance.streamNotifications(authUser.uid)
        : Stream.value(MockDataService.instance.notifications);

    final complaintsStream = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
        ? FirestoreService.instance.streamComplaints(authUser.uid)
        : Stream.value(MockDataService.instance.complaints);

    return ListenableBuilder(
      listenable: MockDataService.instance,
      builder: (context, child) {
        return StreamBuilder<UserModel?>(
          stream: userStream,
          initialData: MockDataService.instance.currentUser,
          builder: (context, userSnap) {
            final user = userSnap.data ?? MockDataService.instance.currentUser;

            return StreamBuilder<List<NotificationModel>>(
              stream: notificationsStream,
              initialData: (!FirestoreService.instance.isFirebaseInitialized)
                  ? MockDataService.instance.notifications
                  : null,
              builder: (context, notifSnap) {
                final rawNotifs = notifSnap.data ?? [];
                final unreadCount = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
                    ? rawNotifs
                        .where((n) => !n.isAnnouncement && n.complaintId != null && n.complaintId!.isNotEmpty && !n.isRead)
                        .length
                    : MockDataService.instance.unreadNotificationCount;

                return Scaffold(
                  backgroundColor: AppColors.background,
                  body: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Navy Header Container
                        _buildHeader(context, user, unreadCount),

                        // Main Content
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Quick Actions Section
                              const Text(
                                'Quick Actions',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),

                              _buildQuickActionsGrid(context),

                              const SizedBox(height: 24),

                              // Recent Complaints Section
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Recent Complaints',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => onNavigateToTab(1),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'View All',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Complaint Cards List
                              StreamBuilder<List<ComplaintModel>>(
                                stream: complaintsStream,
                                initialData: (!FirestoreService.instance.isFirebaseInitialized)
                                    ? MockDataService.instance.complaints
                                    : null,
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    debugPrint('Diagnostic: Error loading recent complaints: ${snapshot.error}');
                                    return Container(
                                      padding: const EdgeInsets.all(24),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        'Unable to load recent complaints.',
                                        style: TextStyle(color: AppColors.textSecondary),
                                      ),
                                    );
                                  }

                                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(24.0),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    );
                                  }

                                  final complaints = snapshot.data ?? [];
                                  if (complaints.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(24),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        'No complaints submitted yet.',
                                        style: TextStyle(color: AppColors.textSecondary),
                                      ),
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: complaints.take(3).map((complaint) {
                                      return ComplaintCard(
                                        complaint: complaint,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ComplaintDetailsScreen(
                                                complaint: complaint,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user, int unreadCount) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TCE Logo, College Name & Notification Bell
              Row(
                children: [
                  // TCE Logo
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/tce_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // College Name
                  Expanded(
                    child: Text(
                      AppConstants.collegeName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Notification Bell
                  GestureDetector(
                    onTap: () => onNavigateToTab(2),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Badge(
                        isLabelVisible: unreadCount > 0,
                        label: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ComplaintHub Title
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              // Student Identity Mini Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${user.registerNumber} • ${user.department}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        _buildActionTile(
          context: context,
          icon: Icons.edit_note_rounded,
          title: 'Submit Complaint',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubmitComplaintScreen()),
            );
          },
        ),

        _buildActionTile(
          context: context,
          icon: Icons.folder_open_rounded,
          title: 'My Complaints',
          onTap: () => onNavigateToTab(1),
        ),

        _buildActionTile(
          context: context,
          icon: Icons.location_on_outlined,
          title: 'Track Complaint',
          onTap: () => onNavigateToTab(1),
        ),

        _buildActionTile(
          context: context,
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          onTap: () => onNavigateToTab(2),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.accent),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                title,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
