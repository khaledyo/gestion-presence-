import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminManageStudentsPage extends StatefulWidget {
  final String userName;
  final String userUid;

  const AdminManageStudentsPage({
    Key? key,
    required this.userName,
    required this.userUid,
  }) : super(key: key);

  @override
  State<AdminManageStudentsPage> createState() => _AdminManageStudentsPageState();
}

class _AdminManageStudentsPageState extends State<AdminManageStudentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedFilter = 'Tous';

  final List<String> _filters = ['Tous', '1ère année', '2ème année', '3ème année'];
  final List<String> _levels = ['1ère année', '2ème année', '3ème année'];

  final Map<String, String> _imageCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _getProfileImageUrl(String userId, Map<String, dynamic>? studentData) async {
    // Vérifier d'abord si l'image est dans le cache
    if (_imageCache.containsKey(userId)) {
      return _imageCache[userId];
    }

    try {
      // 1. Vérifier si l'URL est directement dans les données de l'étudiant
      final directUrl = studentData?['profilePicture'] ?? studentData?['profileImageUrl'];
      if (directUrl != null && directUrl is String && directUrl.isNotEmpty) {
        _imageCache[userId] = directUrl;
        return directUrl;
      }

      // 2. Essayer Firebase Storage
      try {
        final ref = FirebaseStorage.instance.ref().child('profile_images/$userId.jpg');
        final url = await ref.getDownloadURL();
        _imageCache[userId] = url;
        return url;
      } catch (e) {
        // 3. Essayer le chemin alternatif
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

  Future<List<Map<String, dynamic>>> _getAllStudents() async{ try {
  // 1. Récupérer tous les étudiants et classes en parallèle
  final futures = await Future.wait([
  FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Étudiant').get(),
  FirebaseFirestore.instance.collection('school_classes').get(),
  ]);

  final usersSnapshot = futures[0] as QuerySnapshot;
  final classesSnapshot = futures[1] as QuerySnapshot;

  // Créer une map des classes pour accès rapide
  final classesMap = <String, Map<String, dynamic>>{};
  final studentsInClasses = <String, Map<String, dynamic>>{};

  for (final classDoc in classesSnapshot.docs) {
  final classData = classDoc.data() as Map<String, dynamic>;
  final classId = classDoc.id;

  classesMap[classId] = {
  'name': classData['name'] ?? 'Sans nom',
  'level': classData['level'] ?? 'Non spécifié',
  };

  // Récupérer les étudiants de cette classe
  final students = classData['students'] as List<dynamic>? ?? [];
  final studentUids = classData['studentUids'] as List<dynamic>? ?? [];
  final studentIds = studentUids.isNotEmpty ? studentUids : students;

  for (final studentId in studentIds) {
  if (studentId is String) {
  studentsInClasses[studentId] = {
  'classId': classId,
  'className': classData['name'] ?? 'Sans nom',
  'level': classData['level'] ?? 'Non spécifié',
  };
  }
  }
  }

  // 2. Traiter les étudiants
  final allStudents = <Map<String, dynamic>>[];

  for (final userDoc in usersSnapshot.docs) {
  final data = userDoc.data() as Map<String, dynamic>;
  final studentId = userDoc.id;

  // Déterminer la classe et le niveau
  String? classId = data['classId'];
  String? className = data['className'];
  String level = data['level'] ?? 'Non spécifié';

  // Vérifier si l'étudiant est dans une classe
  final classInfo = studentsInClasses[studentId];
  if (classInfo != null) {
  classId = classInfo['classId'];
  className = classInfo['className'];
  level = classInfo['level'];
  }

  // Gérer les références de classe
  if (classId == null && data.containsKey('classReference')) {
  try {
  final classRef = data['classReference'] as DocumentReference;
  final classData = classesMap[classRef.id];
  if (classData != null) {
  classId = classRef.id;
  className = classData['name'];
  level = classData['level'];
  }
  } catch (e) {
  print('Erreur récupération classe référence: $e');
  }
  }

  allStudents.add({
  'id': studentId,
  'source': classInfo != null ? 'class_students' : 'users',
  'nom': data['nom'] ?? data['name'] ?? 'Sans nom',
  'email': data['email'] ?? 'Sans email',
  'level': level,
  'classId': classId,
  'className': className ?? 'Aucune classe',
  'createdAt': data['createdAt'],
  'updatedAt': data['updatedAt'],
  'rawData': data,
  });
  }

  // 3. Ajouter les étudiants référencés dans les classes mais pas dans users
  for (final studentId in studentsInClasses.keys) {
  final studentExists = allStudents.any((student) => student['id'] == studentId);
  if (!studentExists) {
  final classInfo = studentsInClasses[studentId]!;
  allStudents.add({
  'id': studentId,
  'source': 'class_reference',
  'nom': 'Étudiant non trouvé',
  'email': 'ID: $studentId',
  'level': classInfo['level'],
  'classId': classInfo['classId'],
  'className': classInfo['className'],
  'createdAt': null,
  'updatedAt': null,
  'rawData': null,
  });
  }
  }

  return allStudents;

  } catch (e) {
  print('Erreur lors de la récupération des étudiants: $e');
  return [];
  }}

  Future<void> _deleteStudent(String studentId, String studentName) async {
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
                  "Supprimer l'étudiant \"$studentName\" ?\n\nCette action est irréversible.",
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
      // Supprimer de la collection users
      await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .delete();

      // Retirer de toutes les classes
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('school_classes')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final classDoc in classesSnapshot.docs) {
        final classData = classDoc.data();
        final students = classData['students'] as List<dynamic>? ?? [];
        final studentUids = classData['studentUids'] as List<dynamic>? ?? [];

        if (students.contains(studentId) || studentUids.contains(studentId)) {
          batch.update(classDoc.reference, {
            'students': FieldValue.arrayRemove([studentId]),
            'studentUids': FieldValue.arrayRemove([studentId]),
            'studentCount': FieldValue.increment(-1),
          });
        }
      }
      await batch.commit();

      // Supprimer l'image de profil de différents emplacements
      try {
        await FirebaseStorage.instance.ref().child('profile_images/$studentId.jpg').delete();
      } catch (e) {}
      try {
        await FirebaseStorage.instance.ref().child('profile_pictures/$studentId.jpg').delete();
      } catch (e) {}

      _showMessage("Étudiant \"$studentName\" supprimé avec succès ✅", isError: false);
      setState(() {}); // Rafraîchir la liste
    } catch (e) {
      _showMessage("Erreur lors de la suppression : $e", isError: true);
    }
  }

  Future<void> _updateStudentClass(String studentId, Map<String, dynamic> studentData) async {
    String? selectedLevel = studentData['level'] == 'Non spécifié' ? null : studentData['level'];
    String? selectedClassId = studentData['classId'];

    final classesSnapshot = await FirebaseFirestore.instance
        .collection('school_classes')
        .get();

    final classes = classesSnapshot.docs;
    final classesByLevel = <String, List<DocumentSnapshot>>{};

    for (final classDoc in classes) {
      final classData = classDoc.data() as Map<String, dynamic>;
      final level = classData['level'] ?? 'Non spécifié';
      if (!classesByLevel.containsKey(level)) {
        classesByLevel[level] = [];
      }
      classesByLevel[level]!.add(classDoc);
    }

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
                          child: Icon(Icons.edit_rounded, color: Color(0xFF1565C0), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Modifier la classe",
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

                    // Sélection du niveau
                    Text(
                      "Niveau *",
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
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedLevel,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF1565C0)),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Non spécifié',
                                  style: TextStyle(
                                    color: Color(0xFF666E7A),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            ..._levels.map((level) {
                              return DropdownMenuItem(
                                value: level,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    level,
                                    style: TextStyle(
                                      color: Color(0xFF1A237E),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedLevel = value;
                              // Réinitialiser la classe si le niveau change
                              if (selectedClassId != null) {
                                final currentClass = classes.firstWhere(
                                      (doc) => doc.id == selectedClassId,
                                  orElse: () => classes.first,
                                );
                                final currentClassLevel = currentClass.data()!['level'] ?? 'Non spécifié';
                                if (currentClassLevel != value) {
                                  selectedClassId = null;
                                }
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sélection de la classe
                    Text(
                      "Classe *",
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
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedClassId,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF1565C0)),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Aucune classe',
                                  style: TextStyle(
                                    color: Color(0xFF666E7A),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            // Afficher toutes les classes ou filtrer par niveau sélectionné
                            ...(selectedLevel != null
                                ? (classesByLevel[selectedLevel!] ?? [])
                                : classes)
                                .map((classDoc) {
                              final classData = classDoc.data() as Map<String, dynamic>;
                              return DropdownMenuItem(
                                value: classDoc.id,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    '${classData['name'] ?? 'Sans nom'} - ${classData['level'] ?? 'Non spécifié'}',
                                    style: TextStyle(
                                      color: Color(0xFF1A237E),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedClassId = value;
                              // Mettre à jour le niveau si une classe est sélectionnée
                              if (value != null) {
                                final selectedClass = classes.firstWhere(
                                      (doc) => doc.id == value,
                                );
                                final classLevel = selectedClass.data()!['level'] ?? 'Non spécifié';
                                if (classLevel != 'Non spécifié') {
                                  selectedLevel = classLevel;
                                }
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

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
                              try {
                                final batch = FirebaseFirestore.instance.batch();
                                final userRef = FirebaseFirestore.instance.collection('users').doc(studentId);

                                // Préparer les données de mise à jour
                                final updateData = <String, dynamic>{
                                  'updatedAt': FieldValue.serverTimestamp(),
                                };

                                // Mettre à jour le niveau
                                if (selectedLevel != null) {
                                  updateData['level'] = selectedLevel;
                                } else {
                                  updateData['level'] = 'Non spécifié';
                                }

                                // Gérer la classe
                                if (selectedClassId != null) {
                                  updateData['classId'] = selectedClassId;
                                  final classDoc = await FirebaseFirestore.instance
                                      .collection('school_classes')
                                      .doc(selectedClassId!)
                                      .get();
                                  if (classDoc.exists) {
                                    final classData = classDoc.data() as Map<String, dynamic>;
                                    updateData['className'] = classData['name'];

                                    // Ajouter l'étudiant à la nouvelle classe
                                    batch.update(classDoc.reference, {
                                      'students': FieldValue.arrayUnion([studentId]),
                                      'studentUids': FieldValue.arrayUnion([studentId]),
                                      'studentCount': FieldValue.increment(1),
                                    });
                                  }
                                } else {
                                  updateData['classId'] = FieldValue.delete();
                                  updateData['className'] = FieldValue.delete();
                                }

                                batch.update(userRef, updateData);

                                // Retirer l'étudiant de l'ancienne classe si nécessaire
                                final oldClassId = studentData['classId'];
                                if (oldClassId != null && oldClassId != selectedClassId) {
                                  final oldClassDoc = await FirebaseFirestore.instance
                                      .collection('school_classes')
                                      .doc(oldClassId)
                                      .get();
                                  if (oldClassDoc.exists) {
                                    batch.update(oldClassDoc.reference, {
                                      'students': FieldValue.arrayRemove([studentId]),
                                      'studentUids': FieldValue.arrayRemove([studentId]),
                                      'studentCount': FieldValue.increment(-1),
                                    });
                                  }
                                }

                                await batch.commit();
                                Navigator.pop(context);
                                _showMessage("Informations mises à jour avec succès ✅", isError: false);
                                setState(() {}); // Rafraîchir la liste
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

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final studentId = student['id'];
    final name = student['nom'];
    final email = student['email'];
    String level = student['level'] ?? 'Non spécifié';
    String className = student['className'] ?? 'Aucune classe';
    final source = student['source'];
    final rawData = student['rawData'];

    // Corriger l'affichage du niveau et de la classe
    if (level == 'Non spécifié' && className != 'Aucune classe') {
      level = 'À déterminer';
    }
    if (className == 'Aucune classe' && student['classId'] != null) {
      className = 'Classe inconnue';
    }

    return FutureBuilder<String?>(
      future: _getProfileImageUrl(studentId, rawData),
      builder: (context, snapshot) {
        final profileImageUrl = snapshot.data;
        final hasProfileImage = profileImageUrl != null &&
            snapshot.connectionState == ConnectionState.done &&
            profileImageUrl.isNotEmpty;

        Color? cardColor;
        if (source == 'class_reference') {
          cardColor = Color(0xFFFF6D00).withOpacity(0.1);
        } else if (source == 'class_error') {
          cardColor = Color(0xFFD32F2F).withOpacity(0.1);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: cardColor ?? Colors.white,
            borderRadius: BorderRadius.circular(20),
            elevation: 8,
            shadowColor: Color(0xFF1565C0).withOpacity(0.3),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(0xFF1565C0).withOpacity(0.2)),
                gradient: cardColor == null ? LinearGradient(
                  colors: [
                    Colors.white,
                    Color(0xFFF8FAFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ) : null,
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
                        // Avatar avec gestion améliorée des images
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
                              onError: (exception, stackTrace) {
                                // En cas d'erreur de chargement d'image
                                print('Erreur chargement image: $exception');
                              },
                            )
                                : null,
                          ),
                          child: hasProfileImage
                              ? null
                              : Icon(Icons.person_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),

                        // Informations de l'étudiant
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
                                  fontStyle: source.contains('error') || source.contains('reference')
                                      ? FontStyle.italic
                                      : FontStyle.normal,
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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF1565C0).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      level,
                                      style: TextStyle(
                                        color: Color(0xFF1565C0),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF00C853).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      className,
                                      style: TextStyle(
                                        color: Color(0xFF00C853),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (source.contains('error') || source.contains('reference'))
                                const SizedBox(height: 4),
                              if (source.contains('error') || source.contains('reference'))
                                Text(
                                  source == 'class_reference'
                                      ? '⚠️ Étudiant non trouvé dans users'
                                      : '⚠️ Erreur de chargement',
                                  style: TextStyle(
                                    color: Color(0xFFFF6D00),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Boutons d'action
                        Column(
                          children: [
                            // Bouton Modifier
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
                                icon: Icon(Icons.edit_rounded, color: Color(0xFF1565C0), size: 20),
                                onPressed: () => _updateStudentClass(studentId, student),
                                tooltip: 'Modifier la classe',
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
                                onPressed: () => _deleteStudent(studentId, name),
                                tooltip: 'Supprimer l\'étudiant',
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

// [Le reste du code reste identique : _buildSearchBar(), _buildStudentsList(), build()...]
// ... (garder les méthodes _buildSearchBar, _buildStudentsList, et build telles quelles)


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
      child: Column(
        children: [
          // Barre de recherche
          Container(
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
                hintText: "Rechercher un étudiant par nom ou email...",
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
          const SizedBox(height: 12),

          // Filtres par niveau
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = selected ? filter : 'Tous';
                      });
                    },
                    selectedColor: Color(0xFF1565C0),
                    backgroundColor: Color(0xFFF8FAFF),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Color(0xFF1A237E),
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Color(0xFF1565C0) : Color(0xFF1565C0).withOpacity(0.3),
                      ),
                    ),
                    elevation: isSelected ? 4 : 0,
                    shadowColor: Color(0xFF1565C0).withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllStudents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement des étudiants...'),
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
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        final students = snapshot.data ?? [];

        // Filtrer les étudiants
        final filteredStudents = students.where((student) {
          final name = student['nom']?.toString().toLowerCase() ?? '';
          final email = student['email']?.toString().toLowerCase() ?? '';
          final level = student['level']?.toString() ?? '';
          final className = student['className']?.toString().toLowerCase() ?? '';

          // Filtre de recherche
          final matchesSearch = _searchQuery.isEmpty ||
              name.contains(_searchQuery) ||
              email.contains(_searchQuery) ||
              className.contains(_searchQuery);

          // Filtre par niveau
          final matchesFilter = _selectedFilter == 'Tous' || level == _selectedFilter;

          return matchesSearch && matchesFilter;
        }).toList();

        if (filteredStudents.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.person_search_rounded, size: 64, color: Color(0xFF666E7A)),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty || _selectedFilter != 'Tous'
                      ? 'Aucun étudiant trouvé'
                      : 'Aucun étudiant',
                  style: TextStyle(
                    color: Color(0xFF1A237E),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty || _selectedFilter != 'Tous'
                      ? 'Aucun étudiant ne correspond à votre recherche'
                      : 'Commencez par inscrire des étudiants',
                  style: TextStyle(color: Color(0xFF666E7A), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: filteredStudents.map((student) => _buildStudentCard(student)).toList(),
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
              // Header
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
                                "Gestion des Étudiants",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Administration des comptes étudiants",
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

              // Contenu principal
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSearchBar(),
                      Expanded(child: _buildStudentsList()),
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