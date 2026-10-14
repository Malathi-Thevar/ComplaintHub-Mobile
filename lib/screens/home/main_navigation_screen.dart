import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/mock_data_service.dart';
import '../complaints/complaints_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainNavigationScreenState>();
    state?.setTab(index);
  }

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void setTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

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
            final notifications = snapshot.data ?? [];
            final unreadCount = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
                ? notifications
                    .where((n) => !n.isRead && !n.isAnnouncement && n.complaintId != null && n.complaintId!.isNotEmpty)
                    .length
                : MockDataService.instance.unreadNotificationCount;

            final screens = [
              HomeScreen(onNavigateToTab: setTab),
              const ComplaintsListScreen(),
              const NotificationsScreen(),
              const ProfileScreen(),
            ];

            return Scaffold(
              body: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: setTab,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              elevation: 0,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_outlined),
                  activeIcon: Icon(Icons.assignment),
                  label: 'Complaints',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(
                      unreadCount.toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  activeIcon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(
                      unreadCount.toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    child: const Icon(Icons.notifications),
                  ),
                  label: 'Alerts',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);
  }
}
