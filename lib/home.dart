import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final String userName;
  final String role;

  const HomePage({Key? key, required this.userName, required this.role})
      : super(key: key);

  static const Color primaryColor = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ===== APPBAR =====
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: primaryColor,
              child: Icon(Icons.group, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestion de Présence',
                  style: TextStyle(
                    fontSize: 18,
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pushReplacementNamed(context, 'login');
            },
            icon: const Icon(Icons.logout, size: 18, color: primaryColor),
            label: const Text(
              'Déconnexion',
              style: TextStyle(color: primaryColor),
            ),
          ),
        ],
      ),

      // ===== BODY =====
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Bienvenue, $userName 👋",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 20),

              // Texte de rôle
              Text(
                role == "Étudiant"
                    ? "📚 Fonctions Étudiant :"
                    : "👩‍🏫 Fonctions Enseignant :",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 15),

              // Liste des cartes
              Expanded(
                child: ListView(
                  children: role == "Enseignant"
                      ? [
                    _buildClassCard(
                      image: 'assets/class1.jpg',
                      title: "Gérer mes classes",
                      subtitle: "Accédez à la liste de vos classes",
                      onTap: () {},
                    ),
                    _buildClassCard(
                      image: 'assets/class2.jpg',
                      title: "Scanner les présences (QR Code)",
                      subtitle: "Vérifiez la présence des étudiants",
                      onTap: () {},
                    ),
                  ]
                      : [
                    _buildClassCard(
                      image: 'assets/class1.jpg',
                      title: "Marquer ma présence",
                      subtitle: "Scanner le QR Code pour valider",
                      onTap: () {},
                    ),
                    _buildClassCard(
                      image: 'assets/class2.jpg',
                      title: "Voir mon historique",
                      subtitle: "Consultez vos absences",
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const Divider(thickness: 1, color: Colors.grey),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "Application de gestion de présence",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construction d'une carte de fonction
  Widget _buildClassCard({
    required String image,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          image: DecorationImage(
            image: AssetImage(image),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.3),
              BlendMode.darken,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
