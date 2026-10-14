import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/mock_data_service.dart';
import '../complaints/complaint_details_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authUser = AuthService.instance.currentUser;
    final notificationsStream = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
        ? FirestoreService.instance.streamNotifications(authUser.uid)
        : Stream.value(MockDataService.instance.notifications);

    return ListenableBuilder(
      listenable: MockDataService.instance,
      builder: (context, child) {
        return StreamBuilder<List<NotificationModel>>(
          stream: notificationsStream,
          initialData: (!FirestoreService.instance.isFirebaseInitialized)
              ? MockDataService.instance.notifications
              : null,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Diagnostic: Error loading notifications: ${snapshot.error}');
              return Scaffold(
                backgroundColor: AppColors.background,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Unable to load notifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please check your connection and try again.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final rawNotifications = snapshot.data ?? [];
            // Complaint-only policy: Strictly exclude announcements and require valid complaintId
            final notifications = rawNotifications
                .where((n) => !n.isAnnouncement && n.complaintId != null && n.complaintId!.isNotEmpty)
                .toList();

            final unreadCount = notifications.where((n) => !n.isRead).length;

            final newNotifications = notifications
                .where((n) => n.isNew || !n.isRead)
                .toList();

            final earlierNotifications = notifications
                .where((n) => !n.isNew && n.isRead)
                .toList();

        return Scaffold(
          backgroundColor: AppColors.background,

          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                const Flexible(
                  child: Text(
                    'Notifications',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                if (unreadCount > 0) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unreadCount new',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            actions: [
              TextButton(
                onPressed: unreadCount > 0
                    ? () {
                        final user = AuthService.instance.currentUser;
                        if (user != null) {
                          FirestoreService.instance
                              .markAllNotificationsRead(user.uid);
                        } else {
                          MockDataService.instance
                              .markAllNotificationsRead();
                        }
                      }
                    : null,
                child: Text(
                  'Mark All Read',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: unreadCount > 0
                        ? AppColors.accent
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),

          body: notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_outlined,
                        size: 56,
                        color: AppColors.textMuted.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  children: [
                    if (newNotifications.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),

                      ...newNotifications.map(
                        (n) => _buildNotificationTile(
                          context,
                          n,
                        ),
                      ),
                    ],

                    if (earlierNotifications.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Text(
                          'EARLIER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),

                      ...earlierNotifications.map(
                        (n) => _buildNotificationTile(
                          context,
                          n,
                        ),
                      ),
                    ],
                  ],
                ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    NotificationModel item,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: item.isRead
            ? Colors.white
            : const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isRead
              ? AppColors.border
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: InkWell(
        onTap: () async {
          if (item.complaintId != null && item.complaintId!.isNotEmpty) {
            final authUser = AuthService.instance.currentUser;
            final complaint = await FirestoreService.instance.getComplaintById(
              complaintId: item.complaintId!,
              uid: authUser?.uid ?? '',
            );

            if (context.mounted && complaint != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ComplaintDetailsScreen(
                    complaint: complaint,
                  ),
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification Icon
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: item.isAnnouncement
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.isAnnouncement
                      ? Icons.campaign_rounded
                      : Icons.notifications_active_outlined,
                  size: 20,
                  color: item.isAnnouncement
                      ? const Color(0xFFD97706)
                      : AppColors.accent,
                ),
              ),

              const SizedBox(width: 12),

              // Notification Content
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // Title + Unread Indicator
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),

                        if (!item.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(
                              top: 5,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Description
                    Text(
                      item.description,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Timestamp + Complaint Link
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.timeAgo,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),

                        if (item.complaintId != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '• Tap to view',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
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
}