import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'password_reset_email_page.dart';
import 'admin_home_page.dart';
import 'dashboard_etudiant.dart';
import 'dashboard_enseignant.dart';

class MyLogin extends StatefulWidget {
  const MyLogin({Key? key}) : super(key: key);

  @override
  _MyLoginState createState() => _MyLoginState();
}

class _MyLoginState extends State<MyLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessage("Remplis tous les champs 😊");
      return;
    }

    if (!_emailController.text.contains('@')) {
      _showMessage("Email invalide");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();



      // ✅ CONNEXION AVEC FIREBASE AUTH
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User user = userCredential.user!;
      final String uid = user.uid;



      // ✅ RÉCUPÉRATION DES DONNÉES FIRESTORE
      final DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        _showMessage("❌ Données utilisateur non trouvées dans Firestore");
        setState(() => _isLoading = false);
        return;
      }

      final String userName = userDoc['nom'] ?? 'Utilisateur';
      final String userEmail = userDoc['email'] ?? email;
      final String role = userDoc['role']?.toString().toLowerCase() ?? 'étudiant';



      // ✅ REDIRECTION SELON LE RÔLE
      _redirectUser(role, userName, uid, userEmail);

    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      String message;
      switch (e.code) {
        case 'user-not-found':
          message = "❌ Aucun compte avec cet email";
          break;
        case 'wrong-password':
          message = "❌ Mot de passe incorrect";
          _showPasswordResetSuggestion();
          break;
        case 'invalid-email':
          message = "❌ Format email invalide";
          break;
        case 'user-disabled':
          message = "❌ Compte désactivé";
          break;
        case 'too-many-requests':
          message = "❌ Trop de tentatives. Réessayez plus tard";
          break;
        case 'network-request-failed':
          message = "❌ Problème de connexion internet";
          break;
        default:
          message = "❌  Probléme de connexion";
      }
      _showMessage(message);


    } catch (e) {
      setState(() => _isLoading = false);

      _showMessage("❌ Erreur de connexion");
    }
  }

  void _redirectUser(String role, String userName, String uid, String userEmail) {


    Widget targetPage;

    switch (role) {
      case "admin":
        targetPage = AdminHomePage(userName: userName, userUid: uid);
        break;
      case "enseignant":
        targetPage = DashboardEnseignant(
            userName: userName,
            userUid: uid,
            userEmail: userEmail
        );
        break;
      default:
        targetPage = DashboardEtudiant(userName: userName, userUid: uid);
        break;
    }

    // ✅ NAVIGATION AVEC SUCCÈS
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => targetPage),
    );


  }

  void _showPasswordResetSuggestion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Mot de passe oublié ?"),
        content: Text("Vous avez récemment changé votre mot de passe ?\nUtilisez le nouveau mot de passe."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToResetPassword();
            },
            child: Text("Réinitialiser"),
          ),
        ],
      ),
    );
  }

  void _navigateToResetPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PasswordResetEmailPage()),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: message.contains("✅") ? Colors.green : Color(0xFF0D47A1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );
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
                style: TextStyle(fontSize: 16, color: Color(0xFF212121)),
              ),
              const SizedBox(height: 30),

              // Champs Email
              TextField(
                controller: _emailController,
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
                      vertical: 18, horizontal: 20),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Champs Mot de passe
              TextField(
                controller: _passwordController,
                obscureText: true,
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
                      vertical: 18, horizontal: 20),
                ),
              ),

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _navigateToResetPassword,
                  child: Text(
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
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
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
                  const Text("Vous n'avez pas de compte ? ",
                      style: TextStyle(color: Color(0xFF212121))),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, 'register');
                    },
                    child: const Text(
                      "S'inscrire",
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