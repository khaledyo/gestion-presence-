import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_class_page.dart';
import 'attendance_list.dart';
import 'attendance_stats.dart';

class DashboardEnseignant extends StatefulWidget {
  final String userUid;  // UID Firebase
  final String userName; // Nom  l’enseignant

  const DashboardEnseignant({
    Key? key,
    required this.userUid,
    required this.userName,
  }) : super(key: key);

  static const Color primaryColor = Color(0xFF1A237E);

  @override
  State<DashboardEnseignant> createState() => _DashboardEnseignantState();
}

class _DashboardEnseignantState extends State<DashboardEnseignant> {
  int _selectedIndex = 0;

  // Stream des classes de l'enseignant
  Stream<QuerySnapshot> getClassesStream() {
    return FirebaseFirestore.instance
        .collection('classes')
        .where('enseignantUid', isEqualTo: widget.userUid)
        .snapshots();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void openAttendancePage(Map<String, dynamic> classData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceList(classData: classData),
      ),
    );
  }

  List<Widget> _buildPages() {
    return [
      // MES CLASSES
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Container()),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateClassPage(enseignantUid: widget.userUid),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Créer une classe',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DashboardEnseignant.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: getClassesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('Aucune classe. Créez-en une.'));
                  }

                  return GridView.builder(
                    itemCount: docs.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.95, // plus de hauteur pour le contenu
                    ),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () => openAttendancePage({
                          'id': docs[index].id,
                          ...data,
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.class_, size: 35, color: DashboardEnseignant.primaryColor),
                              const SizedBox(height: 10),
                              Text(
                                data['nom'] ?? 'Sans nom',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: DashboardEnseignant.primaryColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Horaire: ${data['horaire'] ?? ''}',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Nombre d\'étudiants: ${data['nombreEtudiants'] ?? 0}',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const Spacer(),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),

      // PRÉSENCE
      Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.qr_code_scanner, size: 100, color: DashboardEnseignant.primaryColor),
              SizedBox(height: 20),
              Text(
                "Scannez le QR Code généré\nou sélectionnez une classe pour marquer la présence.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
      ),

      // STATISTIQUES
      const AttendanceStats(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: DashboardEnseignant.primaryColor,
              child: Icon(Icons.group, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 16,
                    color: DashboardEnseignant.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Espace Enseignant",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
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
            icon: const Icon(Icons.logout, size: 18, color: DashboardEnseignant.primaryColor),
            label: const Text('Déconnexion', style: TextStyle(color: DashboardEnseignant.primaryColor)),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: SizedBox(
        height: 80,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: DashboardEnseignant.primaryColor,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          iconSize: 30,
          selectedFontSize: 16,
          unselectedFontSize: 14,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.class_), label: 'Mes Classes'),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Présence'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Statistiques'),
          ],
        ),
      ),
    );
  }
}
