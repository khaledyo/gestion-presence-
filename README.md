# 📱 Presence App - Système de Gestion de Présence

[![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3+-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Une application moderne de **gestion de présence** développée avec **Flutter** et **Firebase**, permettant de suivre et d'enregistrer la présence des étudiants en temps réel via des **QR Codes dynamiques**.

## 🎯 Fonctionnalités

### 👨‍🏫 Espace Enseignant
- ✅ **Création et gestion des séances**
- ✅ **Génération de QR Codes temporaires** (15 minutes)
- ✅ **Visualisation en temps réel** des présences/absences
- ✅ **Historique des séances**

### 🧑‍🎓 Espace Étudiant
- ✅ **Scan de QR Codes** via caméra
- ✅ **Liste des classes disponibles**
- ✅ **Suivi des présences personnelles**
- ✅ **Interface intuitive**

### 🧑‍💼 Espace Administrateur
- ✅ **Gestion complète des utilisateurs**
- ✅ **Administration des classes et séances**
- ✅ **Supervision globale** des statistiques
- ✅ **Export des données**

## 🚀 Technologies Utilisées

| Domaine | Technologies |
|---------|--------------|
| **Frontend** | Flutter, Dart, Material Design |
| **Backend** | Firebase Authentication, Firestore, Storage |
| **QR Codes** | `qr_flutter`, `camera` |
| **État** | Provider, StreamBuilder |
| **Sécurité** | Firebase Security Rules |

## 📸 Captures d'écran

<div align="center">

### Authentification
<img src="https://github.com/user-attachments/assets/4f7975e4-5af4-4066-94ab-4ded9f86ba15" width="200" alt="Login"/>
<img src="https://github.com/user-attachments/assets/490c8e35-267f-4af3-9445-07307ebe80d0" width="200" alt="Register"/>

### Enseignant
<img src="https://github.com/user-attachments/assets/dcbd8e62-21dc-4091-b1ef-1cf6a2f90c04" width="200" alt="Teacher Dashboard"/>
<img src="https://github.com/user-attachments/assets/ae110f41-6e8d-4423-8ebd-1a540e4f1d61" width="200" alt="Add Session"/>
<img src="https://github.com/user-attachments/assets/5c385487-6cc4-4f56-8d32-9ab42889f68e" width="200" alt="QR Code"/>

### Étudiant
<img src="https://github.com/user-attachments/assets/6b501a2d-4c49-45e6-bb68-2cfa599857a5" width="200" alt="Student Dashboard"/>
<img src="https://github.com/user-attachments/assets/02a511ce-17e2-499c-b782-7dd70bc59b3f" width="200" alt="Classes"/>
<img src="https://github.com/user-attachments/assets/a1770495-6e18-4919-b6a3-a00e4263b989" width="200" alt="Scanner"/>

### Administration
<img src="https://github.com/user-attachments/assets/e532a360-d1e0-4773-baba-7706d968eaa4" width="300" alt="Admin Panel"/>

</div>

## ⚡ Installation

### Prérequis
- Flutter 3.19+ 
- Dart 3.3+
- Compte Firebase
- Android Studio / Xcode (pour le build)

### 🛠️ Configuration

1. **Cloner le projet**
```bash
git clone https://github.com/khaledyo/gestion-presence-.git
cd presence_app
