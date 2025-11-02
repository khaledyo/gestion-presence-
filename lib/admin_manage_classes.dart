import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardAdmin {
  static const Color primaryColor = Color(0xFF0D47A1);
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
  final TextEditingController _controller = TextEditingController();
  bool _isAdding = false;

  // Vérifier si la classe existe déjà (insensible à la casse)
  Future<bool> _isClassExists(String className) async {
    try {
      // Méthode 1: Vérifier avec le champ nameLowercase
      final querySnapshot1 = await FirebaseFirestore.instance
          .collection('school_classes')
          .where('nameLowercase', isEqualTo: className.toLowerCase())
          .get();

      if (querySnapshot1.docs.isNotEmpty) {
        return true;
      }

      // Méthode 2: Vérifier manuellement tous les documents
      final querySnapshot2 = await FirebaseFirestore.instance
          .collection('school_classes')
          .get();

      for (final doc in querySnapshot2.docs) {
        final existingName = doc['name']?.toString().toLowerCase() ?? '';
        if (existingName == className.toLowerCase()) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print("Erreur lors de la vérification: $e");
      return false;
    }
  }

  // Mettre à jour les classes existantes avec le champ nameLowercase
  Future<void> _updateExistingClasses() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('school_classes')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in querySnapshot.docs) {
        final name = doc['name']?.toString() ?? '';
        final nameLowercase = doc['nameLowercase']?.toString();

        // Si le champ nameLowercase n'existe pas ou est différent, on le met à jour
        if (name.isNotEmpty && nameLowercase != name.toLowerCase()) {
          batch.update(doc.reference, {
            'nameLowercase': name.toLowerCase(),
          });
        }
      }

      await batch.commit();
      print("Classes existantes mises à jour avec nameLowercase");
    } catch (e) {
      print("Erreur lors de la mise à jour: $e");
    }
  }

  Future<void> _addClass() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      _showMessage("Veuillez entrer un nom de classe");
      return;
    }

    setState(() => _isAdding = true);

    try {
      // Vérifier si la classe existe déjà
      final bool classExists = await _isClassExists(name);
      if (classExists) {
        _showMessage("La classe \"$name\" existe déjà", isError: true);
        return;
      }

      // Ajouter la nouvelle classe
      await FirebaseFirestore.instance.collection('school_classes').add({
        'name': name,
        'nameLowercase': name.toLowerCase(), // Stocker en minuscule pour la vérification
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.userUid,
      });

      _controller.clear();
      _showMessage("Classe \"$name\" ajoutée avec succès", isError: false);
    } catch (e) {
      _showMessage("Erreur lors de l'ajout : $e", isError: true);
    } finally {
      setState(() => _isAdding = false);
    }
  }

  // Compter le nombre d'étudiants dans une classe
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

  // Supprimer la classe et désaffecter les étudiants
  Future<void> _deleteClass(String docId, String name) async {
    // Compter les étudiants dans cette classe
    final studentCount = await _countStudentsInClass(docId);

    String confirmationMessage;
    if (studentCount > 0) {
      confirmationMessage = "Supprimer la classe \"$name\" ?\n\n⚠️ Cette action affectera $studentCount étudiant(s) qui seront désaffectés de cette classe.";
    } else {
      confirmationMessage = "Supprimer la classe \"$name\" ?";
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(confirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Désaffecter tous les étudiants de cette classe
      if (studentCount > 0) {
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Étudiant')
            .where('classId', isEqualTo: docId)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (final studentDoc in studentsSnapshot.docs) {
          batch.update(studentDoc.reference, {
            'classId': FieldValue.delete(), // Supprimer la référence à la classe
            'classDeletedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      // 2. Supprimer la classe
      await FirebaseFirestore.instance
          .collection('school_classes')
          .doc(docId)
          .delete();

      String successMessage = "Classe \"$name\" supprimée avec succès";
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
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Mettre à jour les classes existantes au chargement
    _updateExistingClasses();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAddCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: "Nom de la classe (ex: TI12)",
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _addClass(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isAdding ? null : _addClass,
            icon: _isAdding
                ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.add),
            label: const Text("Ajouter"),
            style: ElevatedButton.styleFrom(
              backgroundColor: DashboardAdmin.primaryColor,
              foregroundColor: Colors.white,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('school_classes')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "Aucune classe ajoutée pour le moment.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final name = (doc.data() as Map<String, dynamic>)['name'] ?? '';
            final classId = doc.id;

            return FutureBuilder<int>(
              future: _countStudentsInClass(classId),
              builder: (context, studentSnapshot) {
                final studentCount = studentSnapshot.data ?? 0;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
                  child: ListTile(
                    leading: const Icon(Icons.class_, color: Color(0xFF0D47A1)),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: studentCount > 0
                        ? Text("$studentCount étudiant(s)")
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteClass(classId, name),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Gestion des Classes",
          style: TextStyle(
            color: Color(0xFF0D47A1),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instruction
            const Text(
              "Ajouter une nouvelle classe :",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 10),
            _buildAddCard(),
            const SizedBox(height: 20),

            // Liste des classes
            const Text(
              "Liste des classes :",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }
}