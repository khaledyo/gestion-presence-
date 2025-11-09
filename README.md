# 📱 Presence App

Une application moderne de **gestion de présence** développée avec **Flutter**, **Dart**, et **Firebase**, permettant de suivre et d’enregistrer la présence des étudiants en temps réel via des **QR Codes dynamiques**.

---

## 🚀 Aperçu du projet

L’application vise à simplifier la gestion de la présence au sein des établissements éducatifs.  
Elle propose trois espaces distincts :
- 👨‍🏫 **Espace Enseignant**
- 🧑‍🎓 **Espace Étudiant**
- 🧑‍💼 **Espace Administrateur**

Chaque utilisateur dispose de fonctionnalités adaptées à son rôle, facilitant la communication et le suivi.

---

## 🧩 Stack Technique

- **Frontend :** Flutter (Dart)
- **Backend :** Firebase (Authentication, Firestore, Storage, Realtime Database)
- **Autres outils :**
  - QR Code dynamique (package `qr_flutter`)
  - Gestion de l’état avec `StreamBuilder`
  - Cloud Firestore pour la synchronisation en temps réel

---

## ✨ Fonctionnalités principales

### 🔐 Authentification
- Connexion et inscription sécurisées via **Firebase Authentication**.
- Différenciation automatique des rôles (Admin, Enseignant, Étudiant).

### 👨‍🏫 Enseignant
- Création et gestion des séances.
- Génération automatique d'un **QR Code temporaire (15 min)** pour l'enregistrement de la présence.
- Visualisation en temps réel de la liste des étudiants **présents** et **absents**.

### 🧑‍🎓 Étudiant
- Accès à la liste des classes disponibles.
- Scan du QR Code via la **caméra du téléphone** pour valider la présence.
- Suivi de ses présences enregistrées.

### 🧑‍💼 Administrateur
- Gestion complète des utilisateurs :
  - Ajout / modification / suppression d'étudiants et d'enseignants.
  - Gestion des classes et des séances.
- Supervision globale des présences.

---

## 🖼️ Captures d'écran

<div align="center">

### Page de connexion et inscription
<img width="300" alt="image" src="https://github.com/user-attachments/assets/4f7975e4-5af4-4066-94ab-4ded9f86ba15" />

<img width="300" alt="Register Page" src="https://github.com/user-attachments/assets/490c8e35-267f-4af3-9445-07307ebe80d0" />

### Espace Enseignant
<img width="300" alt="image" src="https://github.com/user-attachments/assets/dcbd8e62-21dc-4091-b1ef-1cf6a2f90c04" />

<img width="300" alt="Add Session" src="https://github.com/user-attachments/assets/ae110f41-6e8d-4423-8ebd-1a540e4f1d61" />
<img width="300" alt="QR Code Page" src="https://github.com/user-attachments/assets/5c385487-6cc4-4f56-8d32-9ab42889f68e" />

### Espace Étudiant

<img width="300" alt="image" src="https://github.com/user-attachments/assets/6b501a2d-4c49-45e6-bb68-2cfa599857a5" />
<img width="300" alt="image" src="https://github.com/user-attachments/assets/02a511ce-17e2-499c-b782-7dd70bc59b3f" />
<img width="300" alt="image" src="https://github.com/user-attachments/assets/a1770495-6e18-4919-b6a3-a00e4263b989" />




### Page Administrateur
<img width="300" alt="Admin Page" src="https://github.com/user-attachments/assets/e532a360-d1e0-4773-baba-7706d968eaa4" />

</div>

---

## 🛠️ Installation et exécution

### 1️⃣ Cloner le projet
```bash
git clone https://github.com/khaledyo/presence_app.git
cd presence_app
