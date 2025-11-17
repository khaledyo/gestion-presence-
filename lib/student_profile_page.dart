// lib/pages/student_profile_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:image_picker/image_picker.dart';

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StudentProfilePage extends StatefulWidget {
  final String userUid;
  final String userName;
  final String userEmail;

  const StudentProfilePage({
    Key? key,
    required this.userUid,
    required this.userName,
    required this.userEmail,
  }) : super(key: key);

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  static const Color primaryColor = Color(0xFF6366F1);

  static const Color backgroundColor = Color(0xFFF8FAFD);
  static const Color surfaceColor = Colors.white;
  static const Color textColor = Color(0xFF2D3748);
  static const Color hintColor = Color(0xFF718096);

  final ImagePicker _imagePicker = ImagePicker();
  String? _userEmail;
  List<String> _associatedClasses = [];

  // Stream pour la photo de profil
  Stream<String?> getProfilePictureStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final userData = snapshot.data() as Map<String, dynamic>;
        return userData['profilePicture'] as String?;
      }
      return null;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchAssociatedClasses();
  }

  Future<void> _fetchUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userEmail = userData['email'] ?? widget.userEmail;
        });
      } else {
        setState(() {
          _userEmail = widget.userEmail;
        });
      }
    } catch (e) {
      print('Erreur récupération email: $e');
      setState(() {
        _userEmail = widget.userEmail;
      });
    }
  }

  Future<void> _fetchAssociatedClasses() async {
    try {
      // Chercher dans school_classes où studentUids contient l'UID de l'étudiant
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('school_classes')
          .where('studentUids', arrayContains: widget.userUid)
          .get();

      final classNames = <String>[];
      for (final doc in classesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final className = data['name'] ?? 'Classe sans nom';
        classNames.add(className);
      }

      setState(() {
        _associatedClasses = classNames;
      });
    } catch (e) {
      print('Erreur récupération classes: $e');
    }
  }

  Future<void> _pickImageFromGallery(StateSetter setState) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        await _uploadProfilePicture(File(image.path), setState);
      }
    } catch (e) {
      _showMessage("Erreur: $e");
    }
  }

  Future<void> _takePhotoWithCamera(StateSetter setState) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        await _uploadProfilePicture(File(image.path), setState);
      }
    } catch (e) {
      _showMessage("Erreur: $e");
    }
  }

  Future<void> _uploadProfilePicture(File image, StateSetter setState) async {
    try {
      _showMessage("📤 Upload vers Cloudinary...");

      if (!await image.exists()) {
        _showMessage("❌ Fichier image non trouvé");
        return;
      }

      print('📁 Début upload Cloudinary...');

      final url = Uri.parse('https://api.cloudinary.com/v1_1/dzv7zgtln/image/upload');
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'presence_app_upload'
        ..fields['folder'] = 'presence_app/profile_pictures'
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          image.path,
          filename: 'profile_${widget.userUid}.jpg',
        ));

      var response = await request.send().timeout(Duration(seconds: 30));
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(responseData);
        var imageUrl = jsonResponse['secure_url'];

        // Sauvegarde dans Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userUid)
            .update({
          'profilePicture': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        _showMessage("✅ Photo uploadée avec Cloudinary !");

      } else {
        _showMessage("❌ Erreur lors de l'upload");
      }

    } catch (e) {
      _showMessage("❌ Erreur: ${e.toString()}");
    }
  }

  Future<void> _deleteProfilePicture(StateSetter setState) async {
    try {
      // Supprimer de Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .update({
        'profilePicture': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showMessage("✅ Photo de profil supprimée");

    } catch (e) {
      _showMessage("❌ Erreur lors de la suppression: ${e.toString()}");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildProfilePhotoSection() {
    return StatefulBuilder(
      builder: (context, setState) {
        return StreamBuilder<String?>(
          stream: getProfilePictureStream(),
          builder: (context, snapshot) {
            final profilePictureUrl = snapshot.data;

            return Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                            ? Image.network(
                          profilePictureUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultProfileAvatar();
                          },
                        )
                            : _buildDefaultProfileAvatar(),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _showPhotoOptions(context, setState),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: surfaceColor,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cliquez sur l\'appareil photo pour modifier',
                  style: TextStyle(
                    color: hintColor,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDefaultProfileAvatar() {
    return Container(
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_outline_rounded,
        size: 40,
        color: primaryColor,
      ),
    );
  }

  void _showPhotoOptions(BuildContext context, StateSetter setState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Modifier la photo de profil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: primaryColor),
                title: Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery(setState);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: primaryColor),
                title: Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhotoWithCamera(setState);
                },
              ),
              StreamBuilder<String?>(
                stream: getProfilePictureStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return ListTile(
                      leading: Icon(Icons.delete_rounded, color: Colors.red),
                      title: Text('Supprimer la photo', style: TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        _deleteProfilePicture(setState);
                      },
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileInfoItem(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: hintColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssociatedClassesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Classes associées',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_associatedClasses.isEmpty)
            Text(
              'Aucune classe associée',
              style: TextStyle(
                color: hintColor,
                fontSize: 14,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _associatedClasses.map((className) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          className,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mon Profil',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // PHOTO DE PROFIL AVEC UPLOAD
                  _buildProfilePhotoSection(),
                  const SizedBox(height: 16),
                  Text(
                    widget.userName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Étudiant",
                    style: TextStyle(
                      color: hintColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  _buildProfileInfoItem(
                      Icons.email_outlined,
                      "Email",
                      _userEmail ?? "Chargement..."
                  ),
                  const SizedBox(height: 16),
                  _buildAssociatedClassesSection(),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushReplacementNamed(context, 'login'),
                      icon: Icon(Icons.logout_outlined, size: 18),
                      label: Text('Déconnexion'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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