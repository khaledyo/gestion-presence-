import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';
import 'admin_home_page.dart';
import 'dashboard_etudiant.dart';
import 'dashboard_enseignant.dart';

class AuthCheck extends StatelessWidget {
  const AuthCheck({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Si on attend la connexion
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si l'utilisateur est connecté
        if (snapshot.hasData) {
          final User user = snapshot.data!;
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final data = userSnapshot.data!;
                final String role = data['role']?.toString().toLowerCase() ?? 'étudiant';
                final String userName = data['nom'] ?? 'Utilisateur';
                final String userEmail = data['email'] ?? user.email ?? '';

                switch (role) {
                  case "admin":
                    return AdminHomePage(userName: userName, userUid: user.uid);
                  case "enseignant":
                    return DashboardEnseignant(
                      userName: userName,
                      userUid: user.uid,
                      userEmail: userEmail,
                    );
                  default:
                    return DashboardEtudiant(userName: userName, userUid: user.uid);
                }
              }

              // Si l'utilisateur est authentifié mais n'a pas de données Firestore (cas rare)
              return const MyLogin();
            },
          );
        }

        // Si l'utilisateur n'est pas connecté
        return const MyLogin();
      },
    );
  }
}