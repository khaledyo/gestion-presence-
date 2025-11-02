// lib/pages/student/dashboard_etudiant.dart
import 'package:flutter/material.dart';

import 'classes_list_page.dart';

class DashboardEtudiant extends StatelessWidget {
  final String userName;
  final String userUid;

  const DashboardEtudiant({
    Key? key,
    required this.userName,
    required this.userUid,
  }) : super(key: key);

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color successColor = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(),
                    const SizedBox(height: 32),
                    _buildActionsGrid(context),
                    const SizedBox(height: 20), // Espace supplémentaire en bas
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Espace Étudiant",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  "Connecté en tant qu'étudiant",
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, 'login');
              },
              icon: Icon(Icons.logout_rounded, color: textSecondary, size: 20),
              tooltip: 'Déconnexion',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.waving_hand_rounded, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Bon retour, $userName !",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 52),
          child: Text(
            "Gérez votre présence et consultez votre historique",
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsGrid(BuildContext context) {
    return GridView(
      shrinkWrap: true, // Important pour éviter le débordement
      physics: const NeverScrollableScrollPhysics(), // Désactive le scroll individuel
      padding: const EdgeInsets.only(bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      children: [
        _buildActionCard(
          icon: Icons.qr_code_scanner_rounded,
          title: "Marquer\nma présence",
          subtitle: "Scanner le QR Code",
          color: primaryColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ClassesListPage(userUid: userUid),
              ),
            );
          },
        ),
        _buildActionCard(
          icon: Icons.history_rounded,
          title: "Historique\nde présence",
          subtitle: "Consulter mes absences",
          color: successColor,
          onTap: () {
            // Navigation vers l'historique
            _showComingSoonSnackbar(context);
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_forward_rounded, color: color, size: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoonSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Fonctionnalité en cours de développement',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}