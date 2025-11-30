import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  final Map<String, String> _imageCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _getProfileImageUrl(String userId, Map<String, dynamic>? teacherData) async {
    if (_imageCache.containsKey(userId)) {
      return _imageCache[userId];
    }

    try {
      final directUrl = teacherData?['profilePicture'] ?? teacherData?['profileImageUrl'];
      if (directUrl != null && directUrl is String && directUrl.isNotEmpty) {
        _imageCache[userId] = directUrl;
        return directUrl;
      }

      try {
        final ref = FirebaseStorage.instance.ref().child('profile_images/$userId.jpg');
        final url = await ref.getDownloadURL();
        _imageCache[userId] = url;
        return url;
      } catch (e) {
        try {
          final ref = FirebaseStorage.instance.ref().child('profile_pictures/$userId.jpg');
          final url = await ref.getDownloadURL();
          _imageCache[userId] = url;
          return url;
        } catch (e2) {
          return null;
        }
      }
    } catch (e) {
      return null;
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Color(0xFFD32F2F) : Color(0xFF00C853),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 3),
        elevation: 6,
      ),
    );
  }

  Future<void> _deleteTeacher(String userId, String teacherName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Color(0xFFD32F2F).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_rounded, color: Color(0xFFD32F2F), size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  'Confirmer la suppression',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Supprimer l'enseignant \"$teacherName\" ?\n\nCette action est irréversible.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF666E7A),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF1A237E),
                          side: BorderSide(color: Color(0xFF1A237E)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 4,
                          shadowColor: Color(0xFFD32F2F).withOpacity(0.3),
                        ),
                        child: const Text('Supprimer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      // Utiliser Cloud Functions pour supprimer l'utilisateur Auth
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('deleteUser');
      await callable.call({'userId': userId});

      // Supprimer l'image de profil
      try {
        await FirebaseStorage.instance.ref().child('profile_images/$userId.jpg').delete();
      } catch (e) {}
      try {
        await FirebaseStorage.instance.ref().child('profile_pictures/$userId.jpg').delete();
      } catch (e) {}

      _showMessage("Enseignant \"$teacherName\" supprimé avec succès ✅", isError: false);
      setState(() {});
    } catch (e) {
      _showMessage("Erreur lors de la suppression : $e", isError: true);
    }
  }

  Future<void> _updateTeacherEmail(String teacherId, String currentEmail, String teacherName) async {
    final emailController = TextEditingController(text: currentEmail);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
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
                            color: Color(0xFF1565C0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.email_rounded, color: Color(0xFF1565C0), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Modifier l'email",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "Nouvel email *",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Color(0xFF1565C0).withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: emailController,
                        style: TextStyle(color: Color(0xFF1A237E), fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "nouvel.email@exemple.com",
                          hintStyle: TextStyle(color: Color(0xFF666E7A)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(height: 8),


                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Color(0xFF1565C0),
                              side: BorderSide(color: Color(0xFF1565C0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final newEmail = emailController.text.trim();

                              if (newEmail.isEmpty) {
                                _showMessage("Veuillez entrer un email", isError: true);
                                return;
                              }

                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(newEmail)) {
                                _showMessage("Format d'email invalide", isError: true);
                                return;
                              }

                              if (newEmail == currentEmail) {
                                _showMessage("Le nouvel email est identique à l'actuel", isError: true);
                                return;
                              }

                              try {
                                // Mettre à jour seulement dans Firestore
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(teacherId)
                                    .update({
                                  'email': newEmail,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });

                                _showMessage("Email mis à jour dans Firestore ✅", isError: false);
                                Navigator.pop(context);
                                setState(() {});
                              } catch (e) {
                                _showMessage("Erreur lors de la mise à jour : $e", isError: true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 4,
                              shadowColor: Color(0xFF1565C0).withOpacity(0.3),
                            ),
                            child: const Text('Modifier'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeacherCard(DocumentSnapshot doc) {
    final teacherId = doc.id;
    final data = doc.data() as Map<String, dynamic>;
    final name = data['nom'] ?? 'Nom inconnu';
    final email = data['email'] ?? 'Email inconnu';
    final subject = data['subject'] ?? 'Non spécifié';

    return FutureBuilder<String?>(
      future: _getProfileImageUrl(teacherId, data),
      builder: (context, snapshot) {
        final profileImageUrl = snapshot.data;
        final hasProfileImage = profileImageUrl != null &&
            snapshot.connectionState == ConnectionState.done &&
            profileImageUrl.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            elevation: 8,
            shadowColor: Color(0xFF1565C0).withOpacity(0.3),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(0xFF1565C0).withOpacity(0.2)),
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    Color(0xFFF8FAFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Color(0xFF42A5F5).withOpacity(0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: hasProfileImage
                                ? null
                                : LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF1565C0).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(2, 4),
                              ),
                            ],
                            image: hasProfileImage
                                ? DecorationImage(
                              image: NetworkImage(profileImageUrl!),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: hasProfileImage
                              ? null
                              : Icon(Icons.school_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),

                        // Informations
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A237E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(
                                  color: Color(0xFF666E7A),
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Color(0xFF1565C0).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  subject,
                                  style: TextStyle(
                                    color: Color(0xFF1565C0),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Boutons d'action
                        Column(
                          children: [
                            // Bouton Modifier Email
                            Container(
                              decoration: BoxDecoration(
                                color: Color(0xFF1565C0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF1565C0).withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(1, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(Icons.email_rounded, color: Color(0xFF1565C0), size: 20),
                                onPressed: () => _updateTeacherEmail(teacherId, email, name),
                                tooltip: 'Modifier l\'email',
                                padding: const EdgeInsets.all(10),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Bouton Supprimer
                            Container(
                              decoration: BoxDecoration(
                                color: Color(0xFFD32F2F).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFD32F2F).withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(1, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(Icons.delete_rounded, color: Color(0xFFD32F2F), size: 20),
                                onPressed: () => _deleteTeacher(teacherId, name),
                                tooltip: 'Supprimer l\'enseignant',
                                padding: const EdgeInsets.all(10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // [Les méthodes _buildSearchBar(), _buildTeachersList() et build() restent identiques]
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1565C0).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Color(0xFF1565C0).withOpacity(0.2)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF1565C0).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          style: TextStyle(color: Color(0xFF1A237E), fontSize: 16),
          decoration: InputDecoration(
            hintText: "Rechercher un enseignant par nom...",
            hintStyle: TextStyle(color: Color(0xFF666E7A)),
            filled: true,
            fillColor: Colors.transparent,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF1565C0)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear_rounded, color: Color(0xFF666E7A)),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
                : null,
          ),
        ),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement des enseignants...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: Color(0xFFD32F2F)),
                const SizedBox(height: 16),
                Text(
                  'Erreur de chargement',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Détail: ${snapshot.error}',
                  style: TextStyle(color: Color(0xFF666E7A), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['nom']?.toString().toLowerCase() ?? '';
          return _searchQuery.isEmpty || name.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.person_search_rounded, size: 64, color: Color(0xFF666E7A)),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Aucun enseignant trouvé'
                      : 'Aucun enseignant',
                  style: TextStyle(
                    color: Color(0xFF1A237E),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Aucun enseignant ne correspond à votre recherche'
                      : 'Commencez par inscrire des enseignants',
                  style: TextStyle(color: Color(0xFF666E7A), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: filteredDocs.map((doc) => _buildTeacherCard(doc)).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFF),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    Color(0xFF1565C0).withOpacity(0.05),
                    Color(0xFF42A5F5).withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Column(
            children: [
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
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1565C0).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Gestion des Enseignants",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Administration des comptes enseignants",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSearchBar(),
                      Expanded(child: _buildTeachersList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}