import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/complaint_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/logout_bottom_sheet.dart';
import '../auth/welcome_screen.dart';
import 'about_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authUser = AuthService.instance.currentUser;
    final complaintsStream = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
        ? FirestoreService.instance.streamComplaints(authUser.uid)
        : Stream.value(MockDataService.instance.complaints);

    final userStream = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
        ? FirestoreService.instance.streamUserProfile(authUser.uid)
        : Stream.value(MockDataService.instance.currentUser);

    return ListenableBuilder(
      listenable: MockDataService.instance,
      builder: (context, child) {
        return StreamBuilder<UserModel?>(
          stream: userStream,
          initialData: MockDataService.instance.currentUser,
          builder: (context, userSnap) {
            final user = userSnap.data ?? MockDataService.instance.currentUser;

            return StreamBuilder<List<ComplaintModel>>(
              stream: complaintsStream,
              initialData: (!FirestoreService.instance.isFirebaseInitialized)
                  ? MockDataService.instance.complaints
                  : null,
              builder: (context, complaintsSnap) {
                final complaints = complaintsSnap.data ?? [];
                final total = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
                    ? complaints.length
                    : MockDataService.instance.totalCount;
                final pending = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
                    ? complaints.where((c) => c.status == ComplaintStatus.pending).length
                    : MockDataService.instance.pendingCount;
                final inProgress = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
                    ? complaints.where((c) => c.status == ComplaintStatus.inProgress).length
                    : MockDataService.instance.inProgressCount;
                final resolved = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
                    ? complaints.where((c) => c.status == ComplaintStatus.resolved).length
                    : MockDataService.instance.resolvedCount;

                return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text(
              'Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Student Identity Navy Card
                _buildIdentityCard(user),
                const SizedBox(height: 16),

                // 2. Metrics 4-Column Row
                _buildMetricsCard(
                  total,
                  pending,
                  inProgress,
                  resolved,
                ),
                const SizedBox(height: 24),

                // 3. Account Section Header
                const Text(
                  'ACCOUNT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                // 4. Menu Options List Card
                _buildMenuCard(context),
                const SizedBox(height: 20),

                // 5. Logout Button
                InkWell(
                  onTap: () {
                    LogoutBottomSheet.show(
                      context,
                      onConfirm: () async {
                        await AuthService.instance.signOut();
                        MockDataService.instance.clearUserData();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const WelcomeScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.logout_rounded,
                          color: AppColors.danger,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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

  Widget _buildIdentityCard(dynamic user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // Top Row: Avatar, Name, Reg No
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 30,
                  color: Colors.white,
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.registerNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildIdentityRow(
                  'Department',
                  user.department,
                ),
                const Divider(
                  color: Colors.white12,
                  height: 16,
                ),
                _buildIdentityRow(
                  'Email',
                  user.email,
                ),
                const Divider(
                  color: Colors.white12,
                  height: 16,
                ),
                _buildIdentityRow(
                  'Year',
                  user.academicYear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Overflow-safe identity row
  Widget _buildIdentityRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 7,
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsCard(
    int total,
    int pending,
    int inProgress,
    int resolved,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          _buildMetricColumn(
            '$total',
            'Total',
            AppColors.textPrimary,
          ),
          _buildMetricDivider(),
          _buildMetricColumn(
            '$pending',
            'Pending',
            AppColors.statusPending,
          ),
          _buildMetricDivider(),
          _buildMetricColumn(
            '$inProgress',
            'In Progress',
            AppColors.statusInProgress,
          ),
          _buildMetricDivider(),
          _buildMetricColumn(
            '$resolved',
            'Resolved',
            AppColors.statusResolved,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(
    String count,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.divider,
    );
  }

  Widget _buildMenuCard(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          _buildMenuTile(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EditProfileScreen(),
                ),
              );
            },
          ),
          const Divider(
            color: AppColors.divider,
            height: 1,
          ),
          _buildMenuTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
          const Divider(
            color: AppColors.divider,
            height: 1,
          ),
          _buildMenuTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HelpSupportScreen(),
                ),
              );
            },
          ),
          const Divider(
            color: AppColors.divider,
            height: 1,
          ),
          _buildMenuTile(
            icon: Icons.info_outline_rounded,
            title: 'About ComplaintHub',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AboutScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        size: 20,
        color: AppColors.textPrimary,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: AppColors.textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 2,
      ),
    );
  }
}