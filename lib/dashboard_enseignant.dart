import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_class_page.dart';
import 'attendance_list.dart';
import 'attendance_stats.dart';

class DashboardEnseignant extends StatefulWidget {
  final String userUid;
  final String userName;

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

  // Liste d'icônes élargie (université / informatique / domaines associés)
  final List<IconData> classIcons = const [
    Icons.school,
    Icons.menu_book,
    Icons.computer,
    Icons.science,
    Icons.architecture,
    Icons.group,
    Icons.calculate,
    Icons.psychology,
    Icons.model_training,
    Icons.code, // programmation
    Icons.memory, // hardware / architecture
    Icons.language, // réseaux / langages
    Icons.storage, // bases de données
    Icons.cloud, // cloud
    Icons.smart_toy, // IA / ML
    Icons.engineering, // génie / génie logiciel
    Icons.laptop_mac, // informatique générale
  ];

  // Stream trié pour avoir les classes les plus récentes en premier
  Stream<QuerySnapshot> getClassesStream() {
    return FirebaseFirestore.instance
        .collection('classes')
        .where('enseignantUid', isEqualTo: widget.userUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void openAttendancePage(String classId, Map<String, dynamic> data) {
    final classData = {
      ...data,
      'id': classId,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceList(
          classData: classData,
          classId: classId,
        ),
      ),
    );
  }

  List<Widget> _buildPages() {
    return [
      // --- MES CLASSES ---
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
                        builder: (_) =>
                            CreateClassPage(enseignantUid: widget.userUid),
                      ),
                    );
                    // pas besoin de setState ici : StreamBuilder rafraîchira
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
                    return const Center(
                        child: Text('Aucune classe. Créez-en une.'));
                  }

                  return GridView.builder(
                    itemCount: docs.length,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      // Récupère l'index de l'icône sauvegardé (fallback à 0)
                      final rawIcon = data['iconIndex'];
                      final int savedIconIndex = (rawIcon is int)
                          ? rawIcon
                          : int.tryParse(rawIcon?.toString() ?? '') ?? 0;

                      final currentIcon = classIcons[
                      savedIconIndex % classIcons.length]; // safe fallback

                      return GestureDetector(
                        onTap: () => openAttendancePage(
                          doc.id,
                          {
                            'nom': data['nom'],
                            'horaire': data['horaire'],
                            'nombreEtudiants':
                            (data['studentsUid'] as List?)?.length ?? 0,
                            'iconIndex': savedIconIndex,
                          },
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: Colors.white,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(currentIcon,
                                  size: 35,
                                  color: DashboardEnseignant.primaryColor),
                              const SizedBox(height: 10),
                              Text(
                                (data['nom'] as String?) ?? 'Sans nom',
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
                                'Horaire: ${(data['horaire'] as String?) ?? ''}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Étudiants: ${(data['studentsUid'] as List?)?.length ?? 0}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
                              ),
                              const Spacer(),
                              const Align(
                                alignment: Alignment.bottomRight,
                                child: Icon(Icons.arrow_forward_ios,
                                    size: 16, color: Colors.grey),
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

      // --- Onglet Présence (simple info) ---
      const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner,
                  size: 100, color: DashboardEnseignant.primaryColor),
              SizedBox(height: 20),
              Text(
                "Sélectionnez une classe dans l'onglet 'Mes Classes'\npour générer le QR Code et marquer la présence.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
      ),

      // --- Statistiques ---
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
            onPressed: () =>
                Navigator.pushReplacementNamed(context, 'login'),
            icon: const Icon(Icons.logout,
                size: 18, color: DashboardEnseignant.primaryColor),
            label: const Text('Déconnexion',
                style: TextStyle(color: DashboardEnseignant.primaryColor)),
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
            BottomNavigationBarItem(
                icon: Icon(Icons.class_), label: 'Mes Classes'),
            BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner), label: 'Présence'),
            BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart), label: 'Statistiques'),
          ],
        ),
      ),
    );
  }
}
