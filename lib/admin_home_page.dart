import 'package:flutter/material.dart';
import 'admin_create_class_page.dart';
import 'admin_manage_classes.dart';
import 'admin_manage_sessions.dart';
import 'admin_manage_students.dart';
import 'admin_manage_teachers.dart';
import 'admin_export_attendance_page.dart';

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
      backgroundColor: Color(0xFFF8FAFD),
      body: Column(
        children: [
          // AppBar personnalisée réduite (conservée telle quelle)
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
                    color: Color(0xFF0c6fdf ),
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

          // Contenu principal avec design 3D moderne
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                children: [
                  // Carte image avec design 3D moderne
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Color(0xFFF0F5FF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF0D47A1).withOpacity(0.15),
                          blurRadius: 25,
                          offset: Offset(0, 12),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.9),
                          blurRadius: 15,
                          offset: Offset(-5, -5),
                          spreadRadius: 1,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.9),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Image avec effet 3D
                        Container(
                          width: 250,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF0D47A1).withOpacity(0.25),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              children: [
                                Image.asset(
                                  'assets/admin.jpg',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.1),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

<<<<<<< HEAD
                        
                        const Text(
                          "Bienvenue Admin",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
=======
                        // Titre avec effet de profondeur
                        ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF0D47A1),
                                Color(0xFF42A5F5),
                              ],
                            ).createShader(bounds);
                          },
                          child: Text(
                            "Bienvenue Admin",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
>>>>>>> f7fafc0 (e)
                          ),
                        ),


                        // Description

                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Boutons d'action avec design 3D
                  Column(
                    children: [
                      _build3DActionButton(
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

                      const SizedBox(height: 18),

                      _build3DActionButton(
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

                      const SizedBox(height: 18),

                      _build3DActionButton(
                        icon: Icons.person,
                        title: "Gestion des Étudiants",
                        subtitle: "Gérer les comptes étudiants",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminManageStudentsPage(
                                userName: userName,
                                userUid: userUid,
                              ),
                            ),
                          );
                        },
                      ),

                      // Dans la liste des boutons d'action, ajoutez :
                      const SizedBox(height: 18),

                      // Dans admin_home_page.dart, remplacez le bouton existant par :

                      _build3DActionButton(
                        icon: Icons.schedule_rounded,
                        title: "Gestion des Séances",
                        subtitle: "Créer, modifier et supprimer les séances",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminManageSessionsPage(
                                userName: userName,
                                userUid: userUid,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      _build3DActionButton(
                        icon: Icons.assignment_outlined,
                        title: "Exporter les Présences",
                        subtitle: "Générer des rapports PDF",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminExportAttendancePage(
                                userName: userName,
                                userUid: userUid,
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

  // Widget réutilisable pour les boutons d'action 3D
  Widget _build3DActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFF0F5FF),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF0D47A1).withOpacity(0.15),
                blurRadius: 20,
                offset: Offset(0, 8),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 12,
                offset: Offset(-6, -6),
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.9),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Effet de lumière subtil
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.2,
                      colors: [
                        Colors.white.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Contenu du bouton
              Row(
                children: [
                  const SizedBox(width: 22),
                  // Icon avec effet 3D
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0D47A1),
                          Color(0xFF42A5F5),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF0D47A1).withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(-2, -2),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D47A1),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Flèche avec effet de profondeur
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Color(0xFFE3F2FD),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(Icons.arrow_forward_ios,
                        color: Color(0xFF0D47A1), size: 16),
                  ),
                  const SizedBox(width: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
