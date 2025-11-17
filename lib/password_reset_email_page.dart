import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetEmailPage extends StatefulWidget {
  const PasswordResetEmailPage({Key? key}) : super(key: key);

  @override
  _PasswordResetEmailPageState createState() => _PasswordResetEmailPageState();
}

class _PasswordResetEmailPageState extends State<PasswordResetEmailPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendResetEmail() async {
    if (_emailController.text.isEmpty) {
      _showMessage("Veuillez entrer votre email");
      return;
    }

    if (!_emailController.text.contains('@')) {
      _showMessage("Email invalide");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String email = _emailController.text.trim();

      // ✅ ENVOYER DIRECTEMENT LE LIEN FIREBASE
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      setState(() => _isLoading = false);

      _showMessage("✅ Vérifiez votre boîte email.");

      // Retour au login après 3 secondes
      Future.delayed(Duration(seconds: 3), () {
        Navigator.pop(context);
      });

    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = "Aucun compte trouvé avec cet email";
          break;
        case 'invalid-email':
          message = "Format d'email invalide";
          break;
        case 'invalid-continue-uri':
          message = "URL de continuation invalide";
          break;
        case 'unauthorized-continue-uri':
          message = "URL de continuation non autorisée";
          break;
        case 'network-request-failed':
          message = "Problème de connexion internet";
          break;
        case 'too-many-requests':
          message = "Trop de tentatives. Réessayez plus tard";
          break;
        default:
          message = "Erreur: ${e.code}";
      }
      _showMessage(message);
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Erreur inattendue: $e");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Color(0xFF0D47A1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Mot de passe oublié",
          style: TextStyle(
            color: Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Illustration
            Container(
              height: 150,
              child: Icon(
                Icons.lock_reset_rounded,
                size: 80,
                color: Color(0xFF0D47A1).withOpacity(0.7),
              ),
            ),
            SizedBox(height: 20),

            // Titre
            Text(
              "Réinitialisation du mot de passe",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              child: Text(
                "Entrez votre adresse email pour recevoir un lien de réinitialisation",
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 30),

            // Champ email
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "Adresse email",
                labelStyle: TextStyle(color: Color(0xFF0D47A1)),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF0D47A1)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 30),

            // Bouton de confirmation
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0D47A1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  "Envoyer le lien",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Information
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF0D47A1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Un lien sécurisé de réinitialisation vous sera envoyé par email. Cliquez sur ce lien pour créer votre nouveau mot de passe.",
                      style: TextStyle(
                        color: Color(0xFF0D47A1),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}