import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login.dart';

class MyRegister extends StatefulWidget {
  const MyRegister({Key? key}) : super(key: key);

  @override
  _MyRegisterState createState() => _MyRegisterState();
}

class _MyRegisterState extends State<MyRegister> {
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedRole;
  String? _selectedClass;
  bool _isLoading = false;

  // Couleurs du thème
  final Color _primaryColor = const Color(0xFF1A237E);
  final Color _successColor = Color(0xFF1A237E);
  final Color _errorColor = Color(0xFF1A237E);
  final Color _backgroundColor = Colors.white;
  final Color _textColor = Color(0xFF424242);

  // Méthode pour gérer les erreurs Firebase
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return "Email déjà utilisé";
      case 'invalid-email':
        return "Email invalide";
      case 'operation-not-allowed':
        return "Inscription non activée";
      case 'weak-password':
        return "Mot de passe trop faible";
      case 'network-request-failed':
        return "Erreur réseau";
      default:
        return "Erreur d'inscription";
    }
  }

  String _getFirestoreErrorMessage(Exception e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return "Permission refusée";
        case 'unavailable':
          return "Service indisponible";
        default:
          return "Erreur base de données";
      }
    }
    return "Erreur inconnue";
  }

  // 🔥 NOUVELLE MÉTHODE : Synchroniser avec la collection classes
  Future<void> _updateClassesCollection(String schoolClassId, String studentUid) async {
    try {
      // Trouver toutes les classes qui utilisent cette school_class
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('schoolClassId', isEqualTo: schoolClassId)
          .get();

      // Mettre à jour chaque classe
      for (final classDoc in classesSnapshot.docs) {
        final classData = classDoc.data();
        final currentStudents = List<String>.from(classData['studentsUid'] ?? []);

        if (!currentStudents.contains(studentUid)) {
          currentStudents.add(studentUid);

          await FirebaseFirestore.instance
              .collection('classes')
              .doc(classDoc.id)
              .update({
            'studentsUid': currentStudents,
            'nombreEtudiants': currentStudents.length,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print("✅ Étudiant ajouté à la classe ${classDoc.id}");
        }
      }
    } catch (e) {
      print("❌ Erreur mise à jour classes: $e");
    }
  }

  // 🔥 MÉTHODE : Ajouter l'étudiant à la classe
  Future<void> _addStudentToClass(String classId, String studentUid) async {
    try {
      final classRef = FirebaseFirestore.instance
          .collection('school_classes')
          .doc(classId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final classDoc = await transaction.get(classRef);

        if (!classDoc.exists) {
          throw Exception("Classe non trouvée");
        }

        final classData = classDoc.data()!;
        List<String> students = [];

        // Récupérer la liste actuelle
        if (classData['students'] != null && classData['students'] is List) {
          students = List<String>.from(classData['students']);
        } else if (classData['studentUids'] != null && classData['studentUids'] is List) {
          students = List<String>.from(classData['studentUids']);
        }

        // Ajouter le nouvel étudiant
        if (!students.contains(studentUid)) {
          students.add(studentUid);

          transaction.update(classRef, {
            'students': students,
            'studentUids': students,
            'updatedAt': FieldValue.serverTimestamp(),
            'studentCount': students.length,
          });
        }
      });

      print("✅ Étudiant $studentUid ajouté à la classe $classId");

      // Synchroniser avec la collection classes
      await _updateClassesCollection(classId, studentUid);

    } catch (e) {
      print("❌ Erreur ajout étudiant à classe: $e");
      throw Exception("Impossible d'ajouter l'étudiant à la classe");
    }
  }

  Future<void> _registerUser() async {
    if (_isLoading) return;

    // Validation des champs
    if (_nomController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _selectedRole == null) {
      _showMessage("Remplissez tous les champs 😅", isError: true);
      return;
    }

    // Validation spécifique pour les étudiants
    if (_selectedRole == 'Étudiant' && _selectedClass == null) {
      _showMessage("Sélectionnez une classe 😅", isError: true);
      return;
    }

    // Validation du mot de passe
    if (_passwordController.text.length < 6) {
      _showMessage("6 caractères minimum", isError: true);
      return;
    }

    // Validation de l'email
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showMessage("Email invalide", isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Créer le compte Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userUid = userCredential.user!.uid;

      // Préparer les données pour Firestore
      Map<String, dynamic> userData = {
        'nom': _nomController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Ajouter la classe uniquement pour les étudiants
      if (_selectedRole == 'Étudiant' && _selectedClass != null) {
        userData['classId'] = _selectedClass;
        userData['classReference'] = FirebaseFirestore.instance
            .collection('school_classes')
            .doc(_selectedClass);

        // Ajouter l'étudiant à la classe dans school_classes
        await _addStudentToClass(_selectedClass!, userUid);
      }

      // Sauvegarder les infos dans Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .set(userData);

      // Afficher un message de succès
      _showMessage("Compte créé avec succès! ✅", isError: false);

      // Rediriger vers la page de login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MyLogin(),
        ),
      );

    } on FirebaseAuthException catch (e) {
      _showMessage(_getErrorMessage(e), isError: true);
    } on FirebaseException catch (e) {
      _showMessage(_getFirestoreErrorMessage(e), isError: true);
    } catch (e) {
      _showMessage("Erreur inattendue", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Méthode pour afficher les messages
  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: _backgroundColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? _errorColor : _successColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: _isLoading ? null : () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Illustration
              Center(
                child: Image.asset(
                  'assets/register.jpg',
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _primaryColor, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_alt_1,
                            size: 80,
                            color: _primaryColor,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "Créer un compte",
                            style: TextStyle(
                              fontSize: 18,
                              color: _primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),

              // Titre
              Text(
                "Créer un compte",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Veuillez remplir le formulaire pour continuer",
                style: TextStyle(
                  fontSize: 16,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 30),

              // Nom
              TextField(
                controller: _nomController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: "Nom complet *",
                  labelStyle: TextStyle(color: _primaryColor),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                ),
              ),
              const SizedBox(height: 15),

              // Email
              TextField(
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Adresse e-mail *",
                  labelStyle: TextStyle(color: _primaryColor),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                ),
              ),
              const SizedBox(height: 15),

              // Mot de passe
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Mot de passe *",
                  labelStyle: TextStyle(color: _primaryColor),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                ),
              ),
              const SizedBox(height: 15),

              // Choix du rôle
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Rôle *",
                  labelStyle: TextStyle(color: _primaryColor),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                ),
                value: _selectedRole,
                items: const [
                  DropdownMenuItem(
                    value: 'Étudiant',
                    child: Text("Étudiant 👨‍🎓"),
                  ),
                  DropdownMenuItem(
                    value: 'Enseignant',
                    child: Text("Enseignant 👩‍🏫"),
                  ),
                ],
                onChanged: _isLoading ? null : (value) {
                  setState(() {
                    _selectedRole = value;
                    if (value != 'Étudiant') {
                      _selectedClass = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 15),

              // Sélection de la classe (uniquement pour les étudiants)
              if (_selectedRole == 'Étudiant') ...[
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('school_classes')
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Erreur de chargement",
                          labelStyle: TextStyle(color: _primaryColor),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                        ),
                        items: const [],
                        onChanged: null,
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Chargement...",
                          labelStyle: TextStyle(color: _primaryColor),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                        ),
                        items: const [],
                        onChanged: null,
                      );
                    }

                    final classes = snapshot.data?.docs ?? [];

                    if (classes.isEmpty) {
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Aucune classe",
                          labelStyle: TextStyle(color: _primaryColor),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                        ),
                        items: const [],
                        onChanged: null,
                      );
                    }

                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: "Classe *",
                        labelStyle: TextStyle(color: _primaryColor),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      ),
                      value: _selectedClass,
                      items: classes.map((doc) {
                        final className = (doc.data() as Map<String, dynamic>)['name'] ?? 'Classe sans nom';
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(className),
                        );
                      }).toList(),
                      onChanged: _isLoading ? null : (value) {
                        setState(() {
                          _selectedClass = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 15),
              ],

              const SizedBox(height: 20),

              // Bouton d'inscription
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text(
                    "S'inscrire",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Aller vers connexion
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Vous avez déjà un compte ? ",
                    style: TextStyle(color: _textColor),
                  ),
                  GestureDetector(
                    onTap: _isLoading ? null : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyLogin(),
                        ),
                      );
                    },
                    child: Text(
                      "Se connecter",
                      style: TextStyle(
                        color: _isLoading ? Colors.grey : _primaryColor,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
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
}