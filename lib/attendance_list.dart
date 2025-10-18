import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Importation du package QR Code

class AttendanceList extends StatelessWidget {
  final Map<String, dynamic> classData;
  const AttendanceList({Key? key, required this.classData}) : super(key: key);

  // Définir une couleur pour le QR Code, pour l'uniformité
  static const Color primaryColor = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    final String className = classData['nom'] ?? 'Classe Inconnue';
    final String uniqueCode = classData['code'] ?? 'Code Non Trouvé';

    return Scaffold(
      appBar: AppBar(
        title: Text(className),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Carte d'information ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Séance Actuelle - Code de Présence',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const Divider(height: 25, thickness: 2),
                    Text(
                      'Classe : $className',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    // Affichage du code unique en clair
                    SelectableText(
                      'Code Unique : $uniqueCode',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- Affichage du QR Code ---
            const Center(
              child: Text(
                'Faites Scanner ce QR Code par les étudiants',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 15),

            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryColor, width: 3),
                ),
                child: QrImageView(
                  // Le QR Code unique de la classe
                  data: uniqueCode,
                  version: QrVersions.auto,
                  size: 250.0,
                  foregroundColor: primaryColor,
                  errorStateBuilder: (c, err) {
                    return const Center(
                      child: Text(
                        'QR Code introuvable!',
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- Bouton pour gérer la liste des présences ---
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implémenter la navigation vers la liste des étudiants
                // et le statut de présence/absence pour cette séance
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Afficher la liste de présence (TODO)')),
                );
              },
              icon: const Icon(Icons.list_alt, color: Colors.white),
              label: const Text(
                'Afficher/Gérer la liste de présence',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}