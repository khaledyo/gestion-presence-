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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A237E)),
          onPressed: () {
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
                ),
              ),
              const SizedBox(height: 30),

              // Titre
              const Text(
                "Créer un compte",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Veuillez remplir le formulaire pour continuer",
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF424242),
                ),
              ),
              const SizedBox(height: 30),

              // Nom
              TextField(
                controller: _nomController,
                decoration: InputDecoration(
                  labelText: "Nom complet",
                  labelStyle: const TextStyle(color: Color(0xFF1A237E)),
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
                decoration: InputDecoration(
                  labelText: "Adresse e-mail",
                  labelStyle: const TextStyle(color: Color(0xFF1A237E)),
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
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Mot de passe",
                  labelStyle: const TextStyle(color: Color(0xFF1A237E)),
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
                  labelText: "Rôle",
                  labelStyle: const TextStyle(color: Color(0xFF1A237E)),
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
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value;
                  });
                },
              ),
              const SizedBox(height: 35),

              // Bouton d'inscription
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_nomController.text.isEmpty ||
                        _emailController.text.isEmpty ||
                        _passwordController.text.isEmpty ||
                        _selectedRole == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                            Text("Veuillez remplir tous les champs 😅")),
                      );
                      return;
                    }

                    try {
                      // Créer le compte Firebase Auth
                      final userCredential = await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                        email: _emailController.text.trim(),
                        password: _passwordController.text.trim(),
                      );

                      // Sauvegarder les infos dans Firestore
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userCredential.user!.uid)
                          .set({
                        'nom': _nomController.text,
                        'email': _emailController.text,
                        'role': _selectedRole,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      // Rediriger vers la page de login
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyLogin(),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Erreur : $e")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
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
                  const Text(
                    "Vous avez déjà un compte ? ",
                    style: TextStyle(color: Color(0xFF424242)),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyLogin(),
                        ),
                      );
                    },
                    child: const Text(
                      "Se connecter",
                      style: TextStyle(
                        color: Color(0xFF1A237E),
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
