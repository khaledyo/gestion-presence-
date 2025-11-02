import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  static const Color secondaryColor = Color(0xFF5C6BC0);
  static const Color backgroundColor = Color(0xFFF8FAFD);
  static const Color surfaceColor = Colors.white;
  static const Color textColor = Color(0xFF2D3748);
  static const Color hintColor = Color(0xFF718096);

  @override
  State<DashboardEnseignant> createState() => _DashboardEnseignantState();
}

class _DashboardEnseignantState extends State<DashboardEnseignant> {
  int _selectedIndex = 0;
  bool _isDeleteMode = false;

  final List<IconData> classIcons = const [
    Icons.school_outlined,
    Icons.menu_book_outlined,
    Icons.computer_outlined,
    Icons.science_outlined,
    Icons.architecture_outlined,
    Icons.groups_outlined,
    Icons.calculate_outlined,
    Icons.psychology_outlined,
    Icons.model_training_outlined,
    Icons.code_outlined,
    Icons.memory_outlined,
    Icons.language_outlined,
    Icons.storage_outlined,
    Icons.cloud_outlined,
    Icons.smart_toy_outlined,
    Icons.engineering_outlined,
    Icons.laptop_mac_outlined,
  ];

  Stream<QuerySnapshot> getClassesStream() {
    return FirebaseFirestore.instance
        .collection('classes')
        .where('enseignantUid', isEqualTo: widget.userUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void openAttendancePage(String classId, Map<String, dynamic> data) {
    if (_isDeleteMode) return;
    final classData = {...data, 'id': classId};

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

  Future<void> deleteClass(String classId) async {
    try {
      await FirebaseFirestore.instance.collection('classes').doc(classId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Classe supprimée avec succès.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: DashboardEnseignant.primaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression : $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Widget> _buildPages() {
    return [
      // --- MES CLASSES ---
      _buildClassesPage(),
      // --- PRÉSENCE ---
      _buildAttendancePage(),
      // --- STATISTIQUES ---
      const AttendanceStats(),
    ];
  }

  Widget _buildClassesPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header avec actions - version responsive
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DashboardEnseignant.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 400;

                return isSmallScreen
                    ? _buildMobileHeader()
                    : _buildTabletHeader();
              },
            ),
          ),
          const SizedBox(height: 20),

          // Liste des classes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getClassesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: DashboardEnseignant.primaryColor,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Erreur de chargement',
                          style: TextStyle(
                            color: DashboardEnseignant.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: docs.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: _getChildAspectRatio(constraints.maxWidth),
                      ),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final rawIcon = data['iconIndex'];
                        final int savedIconIndex = (rawIcon is int)
                            ? rawIcon
                            : int.tryParse(rawIcon?.toString() ?? '') ?? 0;
                        final currentIcon = classIcons[savedIconIndex % classIcons.length];

                        String jourAffiche = data['jourNomComplet'] ?? data['jour'] ?? 'Non défini';
                        final schoolClassName = data['schoolClass'] ?? 'Classe non spécifiée';
                        final studentCount = (data['studentsUid'] as List?)?.length ?? 0;

                        return _buildClassCard(
                          classId: doc.id,
                          data: data,
                          currentIcon: currentIcon,
                          jourAffiche: jourAffiche,
                          schoolClassName: schoolClassName,
                          studentCount: studentCount,
                        );
                      },
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      children: [
        // Première ligne : bouton suppression
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isDeleteMode ? Colors.red.withOpacity(0.1) : DashboardEnseignant.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _isDeleteMode = !_isDeleteMode;
                  });
                },
                icon: Icon(
                  _isDeleteMode ? Icons.close_rounded : Icons.delete_outline_rounded,
                  color: _isDeleteMode ? Colors.red : DashboardEnseignant.primaryColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode suppression',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DashboardEnseignant.textColor,
                    ),
                  ),
                  Text(
                    _isDeleteMode ? 'Appuyez sur ❌ pour supprimer' : 'Activez pour supprimer',
                    style: TextStyle(
                      fontSize: 12,
                      color: DashboardEnseignant.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Deuxième ligne : bouton créer
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateClassPage(enseignantUid: widget.userUid),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nouvelle séance'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DashboardEnseignant.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isDeleteMode ? Colors.red.withOpacity(0.1) : DashboardEnseignant.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              setState(() {
                _isDeleteMode = !_isDeleteMode;
              });
            },
            icon: Icon(
              _isDeleteMode ? Icons.close_rounded : Icons.delete_outline_rounded,
              color: _isDeleteMode ? Colors.red : DashboardEnseignant.primaryColor,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mode suppression',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DashboardEnseignant.textColor,
                ),
              ),
              Text(
                _isDeleteMode ? 'Appuyez sur ❌ pour supprimer' : 'Activez pour supprimer',
                style: TextStyle(
                  fontSize: 12,
                  color: DashboardEnseignant.hintColor,
                ),
              ),
            ],
          ),
        ),
        // Bouton créer une classe
        Container(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateClassPage(enseignantUid: widget.userUid),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nouvelle séance'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DashboardEnseignant.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: DashboardEnseignant.hintColor),
            const SizedBox(height: 16),
            Text(
              'Aucune séance créée',
              style: TextStyle(
                color: DashboardEnseignant.textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre première séance pour commencer',
              style: TextStyle(
                color: DashboardEnseignant.hintColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildAttendancePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DashboardEnseignant.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [


                const SizedBox(height: 12),
                Text(
                  "En cours de developpement .",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: DashboardEnseignant.hintColor,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DashboardEnseignant.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Voir mes séances'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth < 400) return 1; // Mobile très petit
    if (screenWidth < 600) return 2; // Mobile moyen
    if (screenWidth < 900) return 3; // Tablet
    return 4; // Desktop
  }

  double _getChildAspectRatio(double screenWidth) {
    if (screenWidth < 400) return 1.7; // Plus large sur petits écrans
    if (screenWidth < 600) return 1.2;
    return 1.1; // Ratio normal pour grands écrans
  }

  Widget _buildClassCard({
    required String classId,
    required Map<String, dynamic> data,
    required IconData currentIcon,
    required String jourAffiche,
    required String schoolClassName,
    required int studentCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallCard = constraints.maxWidth < 200;

        return Stack(
          children: [
            // Carte principale
            Material(
              color: DashboardEnseignant.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              elevation: 1,
              child: InkWell(
                onTap: () => openAttendancePage(
                  classId,
                  {
                    'nom': data['nom'],
                    'horaireDebut': data['horaireDebut'],
                    'horaireFin': data['horaireFin'],
                    'jour': data['jour'],
                    'nombreEtudiants': studentCount,
                    'iconIndex': data['iconIndex'],
                    'schoolClass': schoolClassName,
                  },
                ),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.all(isSmallCard ? 12 : 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header avec icône et nombre d'étudiants
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: isSmallCard ? 32 : 40,
                            height: isSmallCard ? 32 : 40,
                            decoration: BoxDecoration(
                              color: DashboardEnseignant.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              currentIcon,
                              size: isSmallCard ? 18 : 22,
                              color: DashboardEnseignant.primaryColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: DashboardEnseignant.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.group_rounded,
                                  size: isSmallCard ? 14 : 16,
                                  color: DashboardEnseignant.hintColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  studentCount.toString(),
                                  style: TextStyle(
                                    fontSize: isSmallCard ? 10 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: DashboardEnseignant.textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallCard ? 8 : 12),

                      // Nom de la séance
                      Text(
                        (data['nom'] as String?) ?? 'Sans nom',
                        style: TextStyle(
                          fontSize: isSmallCard ? 14 : 16,
                          fontWeight: FontWeight.w700,
                          color: DashboardEnseignant.textColor,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallCard ? 6 : 8),

                      // Classe school
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: DashboardEnseignant.secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.school_rounded,
                              size: isSmallCard ? 10 : 12,
                              color: DashboardEnseignant.secondaryColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                schoolClassName,
                                style: TextStyle(
                                  fontSize: isSmallCard ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                  color: DashboardEnseignant.secondaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallCard ? 6 : 8),

                      // Date et horaire
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: isSmallCard ? 10 : 12,
                                color: DashboardEnseignant.hintColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  jourAffiche,
                                  style: TextStyle(
                                    fontSize: isSmallCard ? 10 : 12,
                                    color: DashboardEnseignant.hintColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (data['horaireDebut'] != null && data['horaireFin'] != null) ...[
                            SizedBox(height: isSmallCard ? 2 : 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: isSmallCard ? 10 : 12,
                                  color: DashboardEnseignant.hintColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${data['horaireDebut']} - ${data['horaireFin']}',
                                  style: TextStyle(
                                    fontSize: isSmallCard ? 10 : 12,
                                    color: DashboardEnseignant.hintColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      const Spacer(),

                      // Footer avec indication de navigation
                      Container(
                        height: 1,
                        color: Colors.grey.shade200,
                        margin: const EdgeInsets.only(bottom: 3),
                      ),
                      Row(
                        children: [
                          Text(
                            'Voir les présences',
                            style: TextStyle(
                              fontSize: isSmallCard ? 9 : 11,
                              color: DashboardEnseignant.hintColor,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: isSmallCard ? 10 : 12,
                            color: DashboardEnseignant.hintColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bouton de suppression
            if (_isDeleteMode)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: DashboardEnseignant.surfaceColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(
                          'Supprimer la séance',
                          style: TextStyle(
                            color: DashboardEnseignant.textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        content: Text(
                          'Êtes-vous sûr de vouloir supprimer cette séance ? Cette action est irréversible.',
                          style: TextStyle(color: DashboardEnseignant.hintColor),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Annuler',
                              style: TextStyle(color: DashboardEnseignant.hintColor),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await deleteClass(classId);
                    }
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();
    return Scaffold(
      backgroundColor: DashboardEnseignant.backgroundColor,
      appBar: AppBar(
        backgroundColor: DashboardEnseignant.surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;

            return Row(
              children: [
                Container(
                  width: isSmallScreen ? 36 : 40,
                  height: isSmallScreen ? 36 : 40,
                  decoration: BoxDecoration(
                    color: DashboardEnseignant.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: DashboardEnseignant.primaryColor,
                    size: isSmallScreen ? 18 : 20,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userName,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: DashboardEnseignant.textColor,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Espace Enseignant",
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 13,
                        color: DashboardEnseignant.hintColor,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 400;

                return isSmallScreen
                    ? IconButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, 'login'),
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: DashboardEnseignant.primaryColor,
                  ),
                )
                    : TextButton.icon(
                  onPressed: () => Navigator.pushReplacementNamed(context, 'login'),
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 16,
                    color: DashboardEnseignant.primaryColor,
                  ),
                  label: Text(
                    'Déconnexion',
                    style: TextStyle(
                      color: DashboardEnseignant.primaryColor,
                      fontSize: 14,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: DashboardEnseignant.primaryColor.withOpacity(0.2)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: DashboardEnseignant.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 70,
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              selectedItemColor: DashboardEnseignant.primaryColor,
              unselectedItemColor: DashboardEnseignant.hintColor,
              onTap: _onItemTapped,
              iconSize: 24,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              backgroundColor: Colors.transparent,
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _selectedIndex == 0
                          ? DashboardEnseignant.primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: const Icon(Icons.school_outlined),
                  ),
                  label: 'Mes Classes',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _selectedIndex == 1
                          ? DashboardEnseignant.primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: const Icon(Icons.qr_code_scanner),
                  ),
                  label: 'Présence',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _selectedIndex == 2
                          ? DashboardEnseignant.primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: const Icon(Icons.bar_chart),
                  ),
                  label: 'Statistiques',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}