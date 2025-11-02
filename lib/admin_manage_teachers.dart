import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManageTeachersPage extends StatefulWidget {
  final String userName;
  final String userUid;

  const AdminManageTeachersPage({
    Key? key,
    required this.userName,
    required this.userUid,
  }) : super(key: key);

  @override
  State<AdminManageTeachersPage> createState() => _AdminManageTeachersPageState();
}

class _AdminManageTeachersPageState extends State<AdminManageTeachersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _deleteTeacher(String userId, String teacherName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text("Supprimer l'enseignant \"$teacherName\" ?"),
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
      // Supprimer seulement le document Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Enseignant \"$teacherName\" supprimé avec succès"),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (e) {
      String errorMessage = "Erreur lors de la suppression";
      if (e.code == 'permission-denied') {
        errorMessage = "Permission refusée. Vérifiez les règles Firebase.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$errorMessage : ${e.message}"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur inattendue : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSearchBar() {
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
          Icon(Icons.search, color: Color(0xFF0D47A1)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Rechercher un enseignant par nom...",
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTeachersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Enseignant')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  "Erreur de permission\n\n${snapshot.error}",
                  style: TextStyle(color: Colors.orange, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        // Filtrer les résultats selon la recherche
        final filteredDocs = docs.where((doc) {
          final teacherName = doc['nom']?.toString().toLowerCase() ?? '';
          return teacherName.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? "Aucun enseignant trouvé"
                      : "Aucun enseignant ne correspond à \"$_searchQuery\"",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: filteredDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final teacherName = doc['nom'] ?? 'Nom inconnu';
            final teacherEmail = doc['email'] ?? 'Email inconnu';
            final userId = doc.id;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFF0D47A1).withOpacity(0.1),
                  child: Icon(Icons.school, color: Color(0xFF0D47A1)),
                ),
                title: Text(
                  teacherName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(teacherEmail),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTeacher(userId, teacherName),
                  tooltip: 'Supprimer l\'enseignant',
                ),
              ),
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
          "Gestion des Enseignants",
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
            // Barre de recherche
            const Text(
              "Rechercher un enseignant :",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 10),
            _buildSearchBar(),
            const SizedBox(height: 20),

            // Liste des enseignants
            const Text(
              "Liste des enseignants :",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildTeachersList()),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}