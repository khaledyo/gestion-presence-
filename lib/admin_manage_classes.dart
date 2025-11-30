import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardAdmin {
  static const Color primaryColor = Color(0xFF1565C0); // Bleu plus clair
  static const Color secondaryColor = Color(0xFF42A5F5); // Bleu clair
  static const Color accentColor = Color(0xFF2979FF); // Bleu vif
  static const Color backgroundColor = Color(0xFFF8FAFF);
  static const Color surfaceColor = Colors.white;
  static const Color textColor = Color(0xFF1A237E);
  static const Color hintColor = Color(0xFF666E7A);
  static const Color successColor = Color(0xFF00C853);
  static const Color warningColor = Color(0xFFFF6D00);
  static const Color errorColor = Color(0xFFD32F2F);
}

class AdminManageClassesPage extends StatefulWidget {
  final String userName;
  final String userUid;

  const AdminManageClassesPage({
    Key? key,
    required this.userName,
    required this.userUid,
  }) : super(key: key);

  @override
  State<AdminManageClassesPage> createState() => _AdminManageClassesPageState();
}

class _AdminManageClassesPageState extends State<AdminManageClassesPage> {
  final TextEditingController _classNameController = TextEditingController();
  bool _isAdding = false;
  bool _showAddClassDialog = false;
  String? _selectedLevel;

  final List<String> _levels = ['1ère année', '2ème année', '3ème année'];

  Future<bool> _isClassExists(String className, String level) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('school_classes')
          .where('nameLowercase', isEqualTo: className.toLowerCase())
          .where('level', isEqualTo: level)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("Erreur lors de la vérification: $e");
      return false;
    }
  }

  void _openAddClassDialog() {
    setState(() {
      _showAddClassDialog = true;
      _classNameController.clear();
      _selectedLevel = null;
    });
  }

  void _closeAddClassDialog() {
    setState(() {
      _showAddClassDialog = false;
    });
  }

  Future<void> _addClass() async {
    final name = _classNameController.text.trim();
    if (name.isEmpty || _selectedLevel == null) {
      _showMessage("Veuillez remplir tous les champs");
      return;
    }

    setState(() => _isAdding = true);

    try {
      final bool classExists = await _isClassExists(name, _selectedLevel!);
      if (classExists) {
        _showMessage("La classe \"$name\" existe déjà en $_selectedLevel", isError: true);
        return;
      }

      await FirebaseFirestore.instance.collection('school_classes').add({
        'name': name,
        'nameLowercase': name.toLowerCase(),
        'level': _selectedLevel,
        'fullName': '$_selectedLevel - $name',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.userUid,
        'studentCount': 0,
      });

      _classNameController.clear();
      _closeAddClassDialog();
      _showMessage("Classe \"$name\" ajoutée en $_selectedLevel avec succès 🎉", isError: false);
    } catch (e) {
      _showMessage("Erreur lors de l'ajout : $e", isError: true);
    } finally {
      setState(() => _isAdding = false);
    }
  }

  Future<int> _countStudentsInClass(String classId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Étudiant')
          .where('classId', isEqualTo: classId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print("Erreur lors du comptage des étudiants: $e");
      return 0;
    }
  }

  Future<void> _deleteClass(String docId, String name, String level) async {
    final studentCount = await _countStudentsInClass(docId);

    String confirmationMessage;
    if (studentCount > 0) {
      confirmationMessage = "Supprimer la classe \"$name\" ($level) ?\n\n⚠️ Cette action affectera $studentCount étudiant(s) qui seront désaffectés de cette classe.";
    } else {
      confirmationMessage = "Supprimer la classe \"$name\" ($level) ?";
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DashboardAdmin.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirmer la suppression',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(confirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: DashboardAdmin.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (studentCount > 0) {
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Étudiant')
            .where('classId', isEqualTo: docId)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (final studentDoc in studentsSnapshot.docs) {
          batch.update(studentDoc.reference, {
            'classId': FieldValue.delete(),
            'classDeletedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      await FirebaseFirestore.instance
          .collection('school_classes')
          .doc(docId)
          .delete();

      String successMessage = "Classe \"$name\" ($level) supprimée avec succès ✅";
      if (studentCount > 0) {
        successMessage += "\n$studentCount étudiant(s) désaffecté(s)";
      }

      _showMessage(successMessage, isError: false);
    } catch (e) {
      _showMessage("Erreur lors de la suppression : $e", isError: true);
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? DashboardAdmin.errorColor : DashboardAdmin.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 3),
        elevation: 6,
      ),
    );
  }

  Widget _buildAddClassDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: DashboardAdmin.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DashboardAdmin.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add, color: DashboardAdmin.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Nouvelle Classe",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: DashboardAdmin.textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                "Niveau *",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DashboardAdmin.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: DashboardAdmin.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DashboardAdmin.primaryColor.withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLevel,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down_rounded, color: DashboardAdmin.primaryColor),
                    items: _levels.map((level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            level,
                            style: TextStyle(
                              color: DashboardAdmin.textColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLevel = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Nom de la classe *",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DashboardAdmin.textColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _classNameController,
                style: TextStyle(color: DashboardAdmin.textColor, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Ex: TI12, GL12, etc.",
                  hintStyle: TextStyle(color: DashboardAdmin.hintColor),
                  filled: true,
                  fillColor: DashboardAdmin.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  prefixIcon: Icon(Icons.class_, color: DashboardAdmin.primaryColor),
                ),
                onFieldSubmitted: (_) => _addClass(),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _closeAddClassDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DashboardAdmin.primaryColor,
                        side: BorderSide(color: DashboardAdmin.primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isAdding ? null : _addClass,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DashboardAdmin.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: DashboardAdmin.primaryColor.withOpacity(0.3),
                      ),
                      child: _isAdding
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('Ajouter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? '';
    final level = data['level'] ?? 'Non spécifié';
    final classId = doc.id;
    final studentCount = data['studentCount'] ?? 0;

    return FutureBuilder<int>(
      future: _countStudentsInClass(classId),
      builder: (context, studentSnapshot) {
        final actualStudentCount = studentSnapshot.data ?? studentCount;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: DashboardAdmin.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            elevation: 6,
            shadowColor: DashboardAdmin.primaryColor.withOpacity(0.2),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DashboardAdmin.primaryColor.withOpacity(0.1)),
                gradient: LinearGradient(
                  colors: [
                    DashboardAdmin.surfaceColor,
                    DashboardAdmin.surfaceColor,
                    DashboardAdmin.backgroundColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ListTile(
                  dense: true,
                visualDensity: VisualDensity.compact,
                // Supprimer dense et visualDensity pour des cartes plus grandes
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3), // Augmenter le padding
                leading: Container(
                  width: 48, // Augmenter la taille de l'icône
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [DashboardAdmin.primaryColor, DashboardAdmin.accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: DashboardAdmin.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.class_, color: Colors.white, size: 22), // Augmenter la taille de l'icône
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16, // Augmenter la taille du texte
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level,
                      style: TextStyle(
                        color: DashboardAdmin.hintColor,
                        fontSize: 13, // Augmenter la taille du texte
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$actualStudentCount étudiant${actualStudentCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: actualStudentCount > 0 ? DashboardAdmin.successColor : DashboardAdmin.hintColor,
                        fontSize: 13, // Augmenter la taille du texte
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                trailing: Container(
                  decoration: BoxDecoration(
                    color: DashboardAdmin.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.delete_rounded, color: DashboardAdmin.errorColor, size: 20), // Augmenter la taille de l'icône
                    onPressed: () => _deleteClass(classId, name, level),
                    tooltip: 'Supprimer la classe',
                    padding: const EdgeInsets.all(8), // Augmenter le padding
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLevelHeader(String level, int classCount, int studentCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.all(16), // Augmenter le padding
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DashboardAdmin.primaryColor.withOpacity(0.08), DashboardAdmin.secondaryColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardAdmin.primaryColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: DashboardAdmin.primaryColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8), // Augmenter le padding
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [DashboardAdmin.primaryColor, DashboardAdmin.accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: DashboardAdmin.primaryColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            child: Icon(Icons.school_rounded, color: Colors.white, size: 20), // Augmenter la taille de l'icône
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: const TextStyle(
                    fontSize: 18, // Augmenter la taille du texte
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$classCount classe${classCount > 1 ? 's' : ''} • $studentCount étudiant${studentCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: DashboardAdmin.hintColor,
                    fontSize: 13, // Augmenter la taille du texte
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLevelSection(String level, List<DocumentSnapshot> classes) {
    final studentCount = classes.fold<int>(0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      final count = data['studentCount'] ?? 0;
      return sum + (count is int ? count : 0);
    });

    return [
      _buildLevelHeader(level, classes.length, studentCount),
      ...classes.map((doc) => _buildClassCard(doc)),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildClassesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('school_classes')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print("Erreur Firestore: ${snapshot.error}");
          return Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.error_outline_rounded, size: 56, color: DashboardAdmin.errorColor), // Augmenter la taille de l'icône
                const SizedBox(height: 16),
                Text(
                  'Erreur de chargement',
                  style: TextStyle(
                    color: DashboardAdmin.errorColor,
                    fontSize: 16, // Augmenter la taille du texte
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Détail: ${snapshot.error}',
                  style: TextStyle(color: DashboardAdmin.hintColor, fontSize: 14), // Augmenter la taille du texte
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DashboardAdmin.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Augmenter le padding
                  ),
                  child: const Text('Réessayer', style: TextStyle(fontSize: 14)), // Augmenter la taille du texte
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement des classes...', style: TextStyle(fontSize: 14)), // Augmenter la taille du texte
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.class_outlined, size: 56, color: DashboardAdmin.hintColor), // Augmenter la taille de l'icône
                const SizedBox(height: 16),
                Text(
                  'Aucune classe',
                  style: TextStyle(
                    color: DashboardAdmin.textColor,
                    fontSize: 16, // Augmenter la taille du texte
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Commencez par ajouter votre première classe',
                  style: TextStyle(color: DashboardAdmin.hintColor, fontSize: 14), // Augmenter la taille du texte
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _openAddClassDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DashboardAdmin.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Augmenter le padding
                  ),
                  child: const Text('Ajouter une classe', style: TextStyle(fontSize: 14)), // Augmenter la taille du texte
                ),
              ],
            ),
          );
        }

        // Grouper les classes par niveau
        final Map<String, List<DocumentSnapshot>> groupedClasses = {};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final level = data['level'] ?? 'Non spécifié';
          if (!groupedClasses.containsKey(level)) {
            groupedClasses[level] = [];
          }
          groupedClasses[level]!.add(doc);
        }

        // Créer la liste des sections
        final List<Widget> sections = [];

        if (groupedClasses.containsKey('Non spécifié')) {
          sections.addAll(_buildLevelSection('Non spécifié', groupedClasses['Non spécifié']!));
        }

        for (final level in _levels.where((l) => groupedClasses.containsKey(l))) {
          sections.addAll(_buildLevelSection(level, groupedClasses[level]!));
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: sections,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardAdmin.backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // Header avec bleu clair
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                  top: 60,
                  bottom: 20,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [DashboardAdmin.primaryColor, DashboardAdmin.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: DashboardAdmin.primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24), // Augmenter la taille de l'icône
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Gestion des Classes",
                                style: TextStyle(
                                  fontSize: 24, // Augmenter la taille du texte
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Administration des classes par niveau",
                                style: TextStyle(
                                  fontSize: 14, // Augmenter la taille du texte
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Bouton d'ajout
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openAddClassDialog,
                        icon: const Icon(Icons.add_rounded, size: 20), // Augmenter la taille de l'icône
                        label: const Text(
                          "Nouvelle Classe",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600), // Augmenter la taille du texte
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: DashboardAdmin.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14), // Augmenter le padding
                          elevation: 4,
                          shadowColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Liste des classes
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildClassesList(),
                ),
              ),
            ],
          ),

          if (_showAddClassDialog)
            _buildAddClassDialog(),
        ],
      ),
    );
  }
}