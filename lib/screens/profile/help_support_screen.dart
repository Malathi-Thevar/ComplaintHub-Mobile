import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Support Section
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildContactItem(
                    icon: Icons.email_outlined,
                    title: 'Email Grievance Cell',
                    value: AppConstants.contactEmail,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Email copied: ${AppConstants.contactEmail}')),
                      );
                    },
                  ),
                  const Divider(color: AppColors.divider, height: 24),
                  _buildContactItem(
                    icon: Icons.phone_outlined,
                    title: 'Helpdesk Helpline',
                    value: AppConstants.contactPhone,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Calling helpline: 0452-2482240')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // FAQs Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildFaqTile(
                    'How do I submit a complaint?',
                    'Go to the Home screen and tap "Submit Complaint" under Quick Actions, or tap the "+" icon on the My Complaints screen. Fill in the required category, department, and description, then tap Submit.',
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _buildFaqTile(
                    'How long does it take to resolve?',
                    'Departmental grievances are typically reviewed within 24 to 48 hours. Most issues are investigated and resolved within 3 to 5 working days depending on complexity.',
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _buildFaqTile(
                    'Can I track my complaint status?',
                    'Yes! Under "My Complaints", select any complaint to view its interactive timeline, current stage (Submitted, Under Review, In Progress, Resolved), and department remarks.',
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _buildFaqTile(
                    'Who can I contact for urgent issues?',
                    'For urgent safety, medical, or administrative emergencies, please call the college helpline directly at 0452-2482240 or report to your Head of Department.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        question,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          answer,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
