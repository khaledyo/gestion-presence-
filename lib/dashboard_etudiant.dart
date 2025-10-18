import 'package:flutter/material.dart';

class DashboardEtudiant extends StatelessWidget {
  final String userName;
  final String userUid; // 👈 ajouté

  const DashboardEtudiant({
    Key? key,
    required this.userName,
    required this.userUid, // 👈 ajouté
  }) : super(key: key);

  static const Color primaryColor = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: primaryColor,
              child: Icon(Icons.school, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              "Espace Étudiant",
              style: TextStyle(
                fontSize: 18,
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pushReplacementNamed(context, 'login');
            },
            icon: const Icon(Icons.logout, size: 18, color: primaryColor),
            label: const Text('Déconnexion', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              "Bienvenue, $userName 👋",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "UID: $userUid", // 👈 facultatif, juste pour debug
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            _buildCard(
              image: 'assets/class1.jpg',
              title: "Marquer ma présence",
              subtitle: "Scanner le QR Code pour valider",
              onTap: () {},
            ),
            _buildCard(
              image: 'assets/class2.jpg',
              title: "Voir mon historique",
              subtitle: "Consultez vos absences",
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
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
          padding: const EdgeInsets.all(16),
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
                style: const TextStyle(color: Colors.white70, fontSize: 16),
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
