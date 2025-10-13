import 'package:flutter/material.dart';
import 'home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyLogin extends StatefulWidget {
  const MyLogin({Key? key}) : super(key: key);

  @override
  _MyLoginState createState() => _MyLoginState();
}

class _MyLoginState extends State<MyLogin> {
  // 🔹 Les contrôleurs pour email et mot de passe
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  // 🔥 Fonction de connexion Firebase
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs 😅")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔐 Connexion Firebase Auth
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 🔥 Récupération des infos Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      final userName = userDoc['nom'];
      final role = userDoc['role'];

      // ✅ Redirection vers la page d’accueil
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(userName: userName, role: role),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Erreur : ${e.message}";
      if (e.code == 'user-not-found') {
        message = "Aucun utilisateur trouvé avec cet e-mail.";
      } else if (e.code == 'wrong-password') {
        message = "Mot de passe incorrect.";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur inattendue : $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  'assets/login.jpg',
                  height: 265,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 40),

              const Text(
                "Bienvenue ",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Connectez-vous pour continuer",
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 30),

              // Email
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Adresse e-mail",
                  labelStyle: const TextStyle(color: Color(0xFF0D47A1)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 20,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Mot de passe
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Mot de passe",
                  labelStyle: const TextStyle(color: Color(0xFF0D47A1)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 20,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // plus tard tu pourras ajouter reset password ici
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "Mot de passe oublié ?",
                    style: TextStyle(
                      color: Color(0xFF0D47A1),
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Bouton de connexion
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "Se connecter",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Vous n’avez pas de compte ? ",
                    style: TextStyle(color: Color(0xFF212121)),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, 'register');
                    },
                    child: const Text(
                      "S’inscrire",
                      style: TextStyle(
                        color: Color(0xFF0D47A1),
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
