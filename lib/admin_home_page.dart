import 'package:flutter/material.dart';
import 'admin_manage_classes.dart';
import 'admin_manage_teachers.dart';

class AdminHomePage extends StatelessWidget {
  final String userName;
  final String userUid;

  const AdminHomePage({
    Key? key,
    required this.userName,
    required this.userUid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // AppBar personnalisée réduite
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 40,
              bottom: 13,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Color(0xFF0D47A1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF0D47A1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        "Espace Administrateur",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, 'login');
                  },
                  icon: Icon(Icons.logout, color: Color(0xFF0D47A1), size: 20),
                  tooltip: 'Déconnexion',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 40),
                ),
              ],
            ),
          ),

          // Contenu principal
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Carte image avec design moderne
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade300, // Bordure fine grise
                        width: 1.5, // Épaisseur fine
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF0D47A1).withOpacity(0.1),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Image plus grande avec bordures arrondies
                        Container(
                          width: 290,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Color(0xFF0D47A1).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/admin.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Titre
                        const Text(
                          "Bienvenue Admin",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        const Text(
                          "Gérez les classes et utilisateurs de votre établissement",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Boutons d'action
                  Column(
                    children: [
                      // Bouton Gestion des Classes
                      _buildActionButton(
                        icon: Icons.class_,
                        title: "Gestion des Classes",
                        subtitle: "Ajouter et modifier les classes",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminManageClassesPage(
                                userName: userName,
                                userUid: userUid,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 15),

                      // Bouton Gestion des Enseignants
                      _buildActionButton(
                        icon: Icons.school,
                        title: "Gestion des Enseignants",
                        subtitle: "Gérer les comptes enseignants",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminManageTeachersPage(
                                userName: userName,
                                userUid: userUid,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 15),

                      // Bouton Gestion des Étudiants
                      _buildActionButton(
                        icon: Icons.person,
                        title: "Gestion des Étudiants",
                        subtitle: "Gérer les comptes étudiants",
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Gestion des étudiants - Fonctionnalité à venir"),
                              backgroundColor: Color(0xFF0D47A1),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget réutilisable pour les boutons d'action
  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: double.infinity,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            splashColor: Color(0xFF0D47A1).withOpacity(0.1),
            highlightColor: Color(0xFF0D47A1).withOpacity(0.2),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 100),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF0D47A1).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Color(0xFF0D47A1), size: 24),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Color(0xFF0D47A1), size: 16),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}