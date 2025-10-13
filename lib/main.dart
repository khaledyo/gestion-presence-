import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // ✅ généré automatiquement

import 'package:presence_app/login.dart';
import 'package:presence_app/register.dart';
import 'package:presence_app/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: const MyLogin(),
    routes: {
      'register': (context) => const MyRegister(),
      'login': (context) => const MyLogin(),
      'home': (context) => const HomePage(

        userName: "Utilisateur",
        role: "Étudiant",
      ),
    },
  ));
}
