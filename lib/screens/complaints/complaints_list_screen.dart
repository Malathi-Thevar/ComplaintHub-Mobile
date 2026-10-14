import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/complaint_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/complaint_card.dart';
import 'complaint_details_screen.dart';
import 'submit_complaint_screen.dart';

class ComplaintsListScreen extends StatefulWidget {
  const ComplaintsListScreen({super.key});

  @override
  State<ComplaintsListScreen> createState() => _ComplaintsListScreenState();
}

class _ComplaintsListScreenState extends State<ComplaintsListScreen> {
  final _searchController = TextEditingController();
  int _selectedFilterIndex = 0; // 0: All, 1: Pending, 2: In Progress, 3: Resolved

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockDataService.instance,
      builder: (context, child) {
        final authUser = AuthService.instance.currentUser;
        final complaintsStream = (authUser != null && FirestoreService.instance.isFirebaseInitialized)
            ? FirestoreService.instance.streamComplaints(authUser.uid)
            : Stream.value(MockDataService.instance.complaints);

        final initialComplaints = (!FirestoreService.instance.isFirebaseInitialized)
            ? MockDataService.instance.complaints
            : null;

        return StreamBuilder<List<ComplaintModel>>(
          stream: complaintsStream,
          initialData: initialComplaints,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Diagnostic: Error loading complaints: ${snapshot.error}');
              return Scaffold(
                backgroundColor: AppColors.background,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text(
                    'My Complaints',
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
                      Icon(Icons.error_outline, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 14),
                      const Text(
                        'Unable to load complaints',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please check your connection and try again.',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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

            final allComplaints = snapshot.data ?? [];
            final totalCount = allComplaints.length;
            final pendingCount = allComplaints.where((c) => c.status == ComplaintStatus.pending).length;
            final inProgressCount = allComplaints.where((c) => c.status == ComplaintStatus.inProgress).length;
            final resolvedCount = allComplaints.where((c) => c.status == ComplaintStatus.resolved).length;

            // Apply Status Filter
            List<ComplaintModel> filtered = allComplaints;
            if (_selectedFilterIndex == 1) {
              filtered = filtered.where((c) => c.status == ComplaintStatus.pending).toList();
            } else if (_selectedFilterIndex == 2) {
              filtered = filtered.where((c) => c.status == ComplaintStatus.inProgress).toList();
            } else if (_selectedFilterIndex == 3) {
              filtered = filtered.where((c) => c.status == ComplaintStatus.resolved).toList();
            }

            // Apply Search Filter
            final query = _searchController.text.trim().toLowerCase();
            if (query.isNotEmpty) {
              filtered = filtered.where((c) {
                return c.id.toLowerCase().contains(query) ||
                    c.subject.toLowerCase().contains(query) ||
                    c.category.toLowerCase().contains(query) ||
                    c.concernedDepartment.toLowerCase().contains(query);
              }).toList();
            }

            return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                const Text(
                  'My Complaints',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalCount Total',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                tooltip: 'New Complaint',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SubmitComplaintScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Search & Filter Header Container
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search by ID or subject...',
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(0, 'All ($totalCount)'),
                          const SizedBox(width: 8),
                          _buildFilterChip(1, 'Pending ($pendingCount)'),
                          const SizedBox(width: 8),
                          _buildFilterChip(2, 'In Progress ($inProgressCount)'),
                          const SizedBox(width: 8),
                          _buildFilterChip(3, 'Resolved ($resolvedCount)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Complaints List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 56,
                              color: AppColors.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              allComplaints.isEmpty
                                  ? 'No complaints submitted yet'
                                  : 'No complaints found',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              allComplaints.isEmpty
                                  ? 'Tap + at the top right to register a complaint.'
                                  : 'Try selecting a different filter or search term.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final complaint = filtered[index];
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
                        },
                      ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
