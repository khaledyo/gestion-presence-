import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'create_class_page.dart';
import 'attendance_list.dart';
import 'history_details_page.dart';

class DashboardEnseignant extends StatefulWidget {
  final String userUid;
  final String userName;
  final String userEmail;

  const DashboardEnseignant({
    Key? key,
    required this.userUid,
    required this.userName,
    required this.userEmail,
  }) : super(key: key);

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color backgroundColor = Color(0xFFF8FAFD);
  static const Color surfaceColor = Colors.white;
  static const Color textColor = Color(0xFF2D3748);
  static const Color hintColor = Color(0xFF718096);

  @override
  State<DashboardEnseignant> createState() => _DashboardEnseignantState();
}

class _DashboardEnseignantState extends State<DashboardEnseignant> {
  int _selectedIndex = 0;
  bool _isDeleteMode = false;
  bool _isEditMode = false;
  String? _userEmail;
  String _currentUserName = '';

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _fetchUserEmail();
  }

  void _updateUserName(String newName) {
    if (mounted) {
      setState(() {
        _currentUserName = newName;
      });
    }
  }

  // REMPLACEZ la méthode _getProfilePictureUrl() par ceci :
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

  Stream<String?> getUserNameStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final userData = snapshot.data() as Map<String, dynamic>;
        return userData['nom'] as String?;
      }
      return null;
    });
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

        // SAUVEGARDEZ dans Firestore - le StreamBuilder se mettra à jour automatiquement
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
      // Supprimer de Firestore - le StreamBuilder se mettra à jour automatiquement
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

  void _openEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => EditProfileDialog(
        userUid: widget.userUid,
        currentName: _currentUserName,
        onProfileUpdated: _updateUserName,
      ),
    );
  }

  final List<IconData> classIcons = const [
    Icons.school_outlined,
    Icons.menu_book_outlined,
    Icons.computer_outlined,
    Icons.science_outlined,
    Icons.architecture_outlined,
    Icons.groups_outlined,
    Icons.calculate_outlined,
    Icons.psychology_outlined,
    Icons.model_training_outlined,
    Icons.code_outlined,
    Icons.memory_outlined,
    Icons.language_outlined,
    Icons.storage_outlined,
    Icons.cloud_outlined,
    Icons.smart_toy_outlined,
    Icons.engineering_outlined,
    Icons.laptop_mac_outlined,
  ];

  Future<void> _fetchUserEmail() async {
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

  Stream<QuerySnapshot> getClassesStream() {
    return FirebaseFirestore.instance
        .collection('classes')
        .where('enseignantUid', isEqualTo: widget.userUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getHistoryStream() {
    return FirebaseFirestore.instance
        .collection('attendance_history')
        .where('teacherUid', isEqualTo: widget.userUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void openAttendancePage(String classId, Map<String, dynamic> data) {
    if (_isDeleteMode || _isEditMode) return;
    final classData = {...data, 'id': classId};

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceList(
          classData: classData,
          classId: classId,
        ),
      ),
    );
  }

  void _openHistoryDetails(Map<String, dynamic> data, String historyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryDetailsPage(
          historyData: data,
          historyId: historyId,
        ),
      ),
    );
  }

  Future<void> deleteClass(String classId) async {
    try {
      await FirebaseFirestore.instance.collection('classes').doc(classId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Classe supprimée avec succès.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: DashboardEnseignant.primaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression : $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> editClass(String classId, Map<String, dynamic> data) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditClassDialog(
        classId: classId,
        initialData: data,
        enseignantUid: widget.userUid,
        userName: widget.userName,
      ),
    );

    if (result == true) {
      setState(() {
        _isEditMode = false;
      });

      // Forcer le rafraîchissement des données
      await Future.delayed(Duration(milliseconds: 500));
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Séance modifiée avec succès ✅'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: DashboardEnseignant.primaryColor,
        ),
      );
    }
  }

  List<Widget> _buildPages() {
    return [
      _buildClassesPage(),
      _buildHistoriquePage(),
      _buildProfilPage(),
    ];
  }

  Widget _buildClassesPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DashboardEnseignant.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 400;
                return isSmallScreen ? _buildMobileHeader() : _buildTabletHeader();
              },
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getClassesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: DashboardEnseignant.primaryColor,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  print('❌ Erreur chargement classes: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Erreur de chargement',
                          style: TextStyle(
                            color: DashboardEnseignant.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vérifiez votre connexion',
                          style: TextStyle(
                            color: DashboardEnseignant.hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: docs.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: _getChildAspectRatio(constraints.maxWidth),
                      ),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final rawIcon = data['iconIndex'];
                        final int savedIconIndex = (rawIcon is int)
                            ? rawIcon
                            : int.tryParse(rawIcon?.toString() ?? '') ?? 0;
                        final currentIcon = classIcons[savedIconIndex % classIcons.length];

                        String jourAffiche = data['jourNomComplet'] ?? data['jour'] ?? 'Non défini';
                        final schoolClassName = data['schoolClass'] ?? 'Classe non spécifiée';
                        final studentCount = (data['studentsUid'] as List?)?.length ?? 0;

                        return _buildClassCard(
                          classId: doc.id,
                          data: data,
                          currentIcon: currentIcon,
                          jourAffiche: jourAffiche,
                          schoolClassName: schoolClassName,
                          studentCount: studentCount,
                        );
                      },
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isDeleteMode ? Colors.red.withOpacity(0.1) : DashboardEnseignant.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _isDeleteMode = !_isDeleteMode;
                    _isEditMode = false;
                  });
                },
                icon: Icon(
                  _isDeleteMode ? Icons.close_rounded : Icons.delete_outline_rounded,
                  color: _isDeleteMode ? Colors.red : DashboardEnseignant.primaryColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isEditMode ? Colors.orange.withOpacity(0.1) : DashboardEnseignant.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _isEditMode = !_isEditMode;
                    _isDeleteMode = false;
                  });
                },
                icon: Icon(
                  _isEditMode ? Icons.close_rounded : Icons.edit_outlined,
                  color: _isEditMode ? Colors.orange : DashboardEnseignant.primaryColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isDeleteMode ? 'Mode suppression' : _isEditMode ? 'Mode modification' : 'Actions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DashboardEnseignant.textColor,
                    ),
                  ),
                  Text(
                    _isDeleteMode ? 'Appuyez sur ❌ pour supprimer' :
                    _isEditMode ? 'Appuyez sur ✏️ pour modifier' : 'Activez un mode',
                    style: TextStyle(
                      fontSize: 12,
                      color: DashboardEnseignant.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateClassPage(
                    enseignantUid: widget.userUid,
                    userName: widget.userName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nouvelle séance'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DashboardEnseignant.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isDeleteMode ? Colors.red.withOpacity(0.1) : DashboardEnseignant.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              setState(() {
                _isDeleteMode = !_isDeleteMode;
                _isEditMode = false;
              });
            },
            icon: Icon(
              _isDeleteMode ? Icons.close_rounded : Icons.delete_outline_rounded,
              color: _isDeleteMode ? Colors.red : DashboardEnseignant.primaryColor,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isEditMode ? Colors.orange.withOpacity(0.1) : DashboardEnseignant.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
                _isDeleteMode = false;
              });
            },
            icon: Icon(
              _isEditMode ? Icons.close_rounded : Icons.edit_outlined,
              color: _isEditMode ? Colors.orange : DashboardEnseignant.primaryColor,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isDeleteMode ? 'Mode suppression' : _isEditMode ? 'Mode modification' : 'Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DashboardEnseignant.textColor,
                ),
              ),
              Text(
                _isDeleteMode ? 'Appuyez sur ❌ pour supprimer' :
                _isEditMode ? 'Appuyez sur ✏️ pour modifier' : 'Activez un mode',
                style: TextStyle(
                  fontSize: 12,
                  color: DashboardEnseignant.hintColor,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateClassPage(
                    enseignantUid: widget.userUid,
                    userName: widget.userName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nouvelle séance'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DashboardEnseignant.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: DashboardEnseignant.hintColor),
            const SizedBox(height: 16),
            Text(
              'Aucune séance créée',
              style: TextStyle(
                color: DashboardEnseignant.textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre première séance pour commencer',
              style: TextStyle(
                color: DashboardEnseignant.hintColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoriquePage() {
    return StreamBuilder<QuerySnapshot>(
      stream: getHistoryStream(),
      builder: (context, snapshot) {
        print('📊 État historique: ${snapshot.connectionState}');
        print('📊 Données historique: ${snapshot.hasData}');
        print('📊 Erreur historique: ${snapshot.error}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: DashboardEnseignant.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Chargement de l\'historique...',
                  style: TextStyle(
                    color: DashboardEnseignant.hintColor,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          print('❌ Erreur détaillée historique: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Erreur de chargement',
                  style: TextStyle(
                    color: DashboardEnseignant.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Impossible de charger l\'historique. Vérifiez votre connexion Internet.',
                    style: TextStyle(
                      color: DashboardEnseignant.hintColor,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DashboardEnseignant.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyHistory();
        }

        final historyItems = snapshot.data!.docs;
        print('📊 Nombre d\'items historiques: ${historyItems.length}');

        historyItems.sort((a, b) {
          final dateA = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final dateB = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (dateA == null || dateB == null) return 0;
          return dateB.compareTo(dateA);
        });

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: historyItems.length,
          itemBuilder: (context, index) {
            final item = historyItems[index].data() as Map<String, dynamic>;
            print('📊 Item $index: ${item['className']}');
            return _buildHistoryCard(item, historyItems[index].id);
          },
        );
      },
    );
  }

  Widget _buildEmptyHistory() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DashboardEnseignant.surfaceColor,
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
                Icon(Icons.history_rounded, size: 64, color: DashboardEnseignant.hintColor),
                const SizedBox(height: 16),
                Text(
                  'Aucun historique de présence',
                  style: TextStyle(
                    color: DashboardEnseignant.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les présences de vos séances apparaîtront ici automatiquement après chaque cours',
                  style: TextStyle(
                    color: DashboardEnseignant.hintColor,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'Quand une séance se termine, les présences sont automatiquement sauvegardées ici.',
                  style: TextStyle(
                    color: DashboardEnseignant.hintColor,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: DashboardEnseignant.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data, String historyId) {
    try {
      Timestamp? dateTimestamp;

      if (data['date'] != null) {
        dateTimestamp = data['date'] as Timestamp;
      } else if (data['createdAt'] != null) {
        dateTimestamp = data['createdAt'] as Timestamp;
      } else if (data['sessionDate'] != null) {
        dateTimestamp = data['sessionDate'] as Timestamp;
      }

      final date = dateTimestamp?.toDate() ?? DateTime.now();
      final presentCount = data['presentCount'] ?? 0;
      final totalStudents = data['totalStudents'] ?? 0;
      final percentage = totalStudents > 0 ? (presentCount / totalStudents * 100).round() : 0;

      return Card(
        margin: EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DashboardEnseignant.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.history_rounded,
                color: DashboardEnseignant.primaryColor),
          ),
          title: Text(
            data['className'] ?? 'Séance sans nom',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${DateFormat('dd/MM/yyyy').format(date)} • ${data['startTime'] ?? ''}'),
              Text(data['schoolClass'] ?? 'Classe non spécifiée'),
              SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: percentage >= 70 ? Colors.green.withOpacity(0.1) :
                      percentage >= 50 ? Colors.orange.withOpacity(0.1) :
                      Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$presentCount/$totalStudents présents ($percentage%)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: percentage >= 70 ? Colors.green :
                        percentage >= 50 ? Colors.orange :
                        Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () => _openHistoryDetails(data, historyId),
        ),
      );
    } catch (e) {
      print('❌ Erreur affichage carte historique: $e');
      return Card(
        margin: EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(Icons.error_outline_rounded, color: Colors.red),
          title: Text('Erreur d\'affichage'),
          subtitle: Text('Données corrompues'),
        ),
      );
    }
  }

  Widget _buildProfilPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DashboardEnseignant.surfaceColor,
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
                // StreamBuilder pour le nom dans le profil
                StreamBuilder<String?>(
                  stream: getUserNameStream(),
                  builder: (context, snapshot) {
                    final userName = snapshot.hasData && snapshot.data != null
                        ? snapshot.data!
                        : _currentUserName;

                    return Column(
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: DashboardEnseignant.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Enseignant",
                          style: TextStyle(
                            color: DashboardEnseignant.hintColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 20),
                _buildProfileInfoItem(
                    Icons.email_outlined,
                    "Email",
                    _userEmail ?? "Chargement..."
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openEditProfileDialog,
                    icon: Icon(Icons.edit_outlined, size: 18),
                    label: Text('Modifier le profil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DashboardEnseignant.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                          color: DashboardEnseignant.primaryColor.withOpacity(0.3),
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
                                color: DashboardEnseignant.primaryColor,
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
                            color: DashboardEnseignant.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: DashboardEnseignant.surfaceColor,
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
                    color: DashboardEnseignant.hintColor,
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

  // AVATAR PAR DÉFAUT
  Widget _buildDefaultProfileAvatar() {
    return Container(
      decoration: BoxDecoration(
        color: DashboardEnseignant.primaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_outline_rounded,
        size: 40,
        color: DashboardEnseignant.primaryColor,
      ),
    );
  }

  // OPTIONS POUR LA PHOTO
  void _showPhotoOptions(BuildContext context, StateSetter setState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DashboardEnseignant.surfaceColor,
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
                    color: DashboardEnseignant.textColor,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: DashboardEnseignant.primaryColor),
                title: Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery(setState);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: DashboardEnseignant.primaryColor),
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
            color: DashboardEnseignant.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: DashboardEnseignant.primaryColor,
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
                  color: DashboardEnseignant.hintColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DashboardEnseignant.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth < 400) return 1;
    if (screenWidth < 600) return 2;
    if (screenWidth < 900) return 3;
    return 4;
  }

  double _getChildAspectRatio(double screenWidth) {
    if (screenWidth < 400) return 1.7;
    if (screenWidth < 600) return 1.2;
    return 1.1;
  }

  Widget _buildClassCard({
    required String classId,
    required Map<String, dynamic> data,
    required IconData currentIcon,
    required String jourAffiche,
    required String schoolClassName,
    required int studentCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallCard = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth > 600;

        return Stack(
          children: [
            // Carte principale avec effet 3D
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  // Ombre portée pour effet de profondeur
                  BoxShadow(
                    color: DashboardEnseignant.primaryColor.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -2,
                  ),
                  // Ombre interne pour effet d'élévation
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          DashboardEnseignant.surfaceColor.withOpacity(0.9),
                          DashboardEnseignant.surfaceColor.withOpacity(0.7),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => openAttendancePage(
                          classId,
                          {
                            'nom': data['nom'],
                            'horaireDebut': data['horaireDebut'],
                            'horaireFin': data['horaireFin'],
                            'jour': data['jour'],
                            'nombreEtudiants': studentCount,
                            'iconIndex': data['iconIndex'],
                            'schoolClass': schoolClassName,
                            'dateDebut': data['dateDebut'],
                            'dateFin': data['dateFin'],
                          },
                        ),
                        borderRadius: BorderRadius.circular(20),
                        splashColor: DashboardEnseignant.primaryColor.withOpacity(0.1),
                        highlightColor: DashboardEnseignant.primaryColor.withOpacity(0.05),
                        child: Container(
                          padding: EdgeInsets.all(isSmallCard ? 14 : isTablet ? 20 : 18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            // Effet de bordure lumineuse
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // En-tête avec icône et compteur d'étudiants
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Icône avec effet 3D
                                  Container(
                                    width: isSmallCard ? 36 : isTablet ? 50 : 44,
                                    height: isSmallCard ? 36 : isTablet ? 50 : 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          DashboardEnseignant.primaryColor.withOpacity(0.15),
                                          DashboardEnseignant.secondaryColor.withOpacity(0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: DashboardEnseignant.primaryColor.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(2, 2),
                                        ),
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.5),
                                          blurRadius: 8,
                                          offset: const Offset(-2, -2),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // Effet de brillance
                                        Positioned(
                                          top: 4,
                                          left: 4,
                                          child: Container(
                                            width: isSmallCard ? 8 : 12,
                                            height: isSmallCard ? 8 : 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withOpacity(0.3),
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Icon(
                                            currentIcon,
                                            size: isSmallCard ? 18 : isTablet ? 24 : 22,
                                            color: DashboardEnseignant.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Badge étudiant avec effet 3D
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withOpacity(0.9),
                                          Colors.grey.shade100,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.group_rounded,
                                          size: isSmallCard ? 12 : 14,
                                          color: DashboardEnseignant.primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          studentCount.toString(),
                                          style: TextStyle(
                                            fontSize: isSmallCard ? 10 : 12,
                                            fontWeight: FontWeight.w700,
                                            color: DashboardEnseignant.textColor,
                                            shadows: [
                                              Shadow(
                                                color: Colors.white.withOpacity(0.8),
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: isSmallCard ? 10 : isTablet ? 16 : 14),

                              // Nom de la séance avec effet de profondeur
                              ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      DashboardEnseignant.textColor,
                                      DashboardEnseignant.textColor.withOpacity(0.8),
                                    ],
                                  ).createShader(bounds);
                                },
                                child: Text(
                                  (data['nom'] as String?) ?? 'Sans nom',
                                  style: TextStyle(
                                    fontSize: isSmallCard ? 14 : isTablet ? 18 : 16,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              SizedBox(height: isSmallCard ? 8 : isTablet ? 12 : 10),

                              // Badge classe avec effet 3D
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      DashboardEnseignant.secondaryColor.withOpacity(0.1),
                                      DashboardEnseignant.primaryColor.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: DashboardEnseignant.secondaryColor.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: DashboardEnseignant.secondaryColor.withOpacity(0.2),
                                      ),
                                      child: Icon(
                                        Icons.school_rounded,
                                        size: isSmallCard ? 10 : 12,
                                        color: DashboardEnseignant.secondaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        schoolClassName,
                                        style: TextStyle(
                                          fontSize: isSmallCard ? 10 : 11,
                                          fontWeight: FontWeight.w600,
                                          color: DashboardEnseignant.secondaryColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: isSmallCard ? 8 : isTablet ? 12 : 10),

                              // Informations date et heure avec icônes 3D
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Date
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: DashboardEnseignant.primaryColor.withOpacity(0.1),
                                          ),
                                          child: Icon(
                                            Icons.calendar_today_rounded,
                                            size: isSmallCard ? 10 : 12,
                                            color: DashboardEnseignant.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            jourAffiche,
                                            style: TextStyle(
                                              fontSize: isSmallCard ? 10 : 12,
                                              fontWeight: FontWeight.w500,
                                              color: DashboardEnseignant.textColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (data['horaireDebut'] != null && data['horaireFin'] != null) ...[
                                      SizedBox(height: isSmallCard ? 4 : 6),
                                      // Horaire
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: DashboardEnseignant.secondaryColor.withOpacity(0.1),
                                            ),
                                            child: Icon(
                                              Icons.access_time_rounded,
                                              size: isSmallCard ? 10 : 12,
                                              color: DashboardEnseignant.secondaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${data['horaireDebut']} - ${data['horaireFin']}',
                                            style: TextStyle(
                                              fontSize: isSmallCard ? 10 : 12,
                                              fontWeight: FontWeight.w500,
                                              color: DashboardEnseignant.textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const Spacer(),

                              // Séparateur avec effet de profondeur
                              Container(
                                height: 1,
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.5),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),

                              // Footer avec CTA
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  children: [
                                    Text(
                                      'Voir les présences',
                                      style: TextStyle(
                                        fontSize: isSmallCard ? 9 : 11,
                                        fontWeight: FontWeight.w600,
                                        color: DashboardEnseignant.primaryColor,
                                        shadows: [
                                          Shadow(
                                            color: Colors.white.withOpacity(0.8),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            DashboardEnseignant.primaryColor,
                                            DashboardEnseignant.secondaryColor,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: DashboardEnseignant.primaryColor.withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: isSmallCard ? 10 : 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Boutons d'action (suppression/modification) avec effet 3D
            if (_isDeleteMode)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => _build3DConfirmationDialog(),
                    );
                    if (confirm == true) {
                      setState(() {
                        _isDeleteMode = false;
                      });
                      await deleteClass(classId);
                    }
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.red.shade400,
                          Colors.red.shade600,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(-1, -1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),

            if (_isEditMode)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => editClass(classId, data),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(-1, -1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
  Widget _build3DConfirmationDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DashboardEnseignant.surfaceColor.withOpacity(0.95),
              DashboardEnseignant.surfaceColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône d'avertissement 3D
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.shade400,
                      Colors.red.shade600,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Supprimer la séance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: DashboardEnseignant.textColor,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Cette action est irréversible. Voulez-vous vraiment supprimer cette séance ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: DashboardEnseignant.hintColor,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: DashboardEnseignant.textColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Supprimer'),
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
  // AJOUTEZ cette méthode pour l'avatar de fallback dans l'AppBar
  Widget _buildAppBarFallbackAvatar(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: DashboardEnseignant.primaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_rounded,
        color: DashboardEnseignant.primaryColor,
        size: isSmallScreen ? 18 : 20,
      ),
    );
  }

  @override

  Widget build(BuildContext context) {
    final pages = _buildPages();
    return Scaffold(
      backgroundColor: DashboardEnseignant.backgroundColor,
      appBar: AppBar(
        backgroundColor: DashboardEnseignant.surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;

            return GestureDetector(
              onTap: () {
                // Naviguer vers la page Profil
                setState(() {
                  _selectedIndex = 2;
                });
              },
              child: Row(
                children: [
                  // StreamBuilder pour la photo de profil
                  StreamBuilder<String?>(
                    stream: getProfilePictureStream(),
                    builder: (context, snapshot) {
                      final profilePictureUrl = snapshot.data;

                      return Container(
                        width: isSmallScreen ? 44 : 40,
                        height: isSmallScreen ? 44 : 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DashboardEnseignant.primaryColor.withOpacity(0.3),
                            width: 1,
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
                                  color: DashboardEnseignant.primaryColor,
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return _buildAppBarFallbackAvatar(isSmallScreen);
                            },
                          )
                              : _buildAppBarFallbackAvatar(isSmallScreen),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  // StreamBuilder pour le nom
                  StreamBuilder<String?>(
                    stream: getUserNameStream(),
                    builder: (context, snapshot) {
                      final userName = snapshot.hasData && snapshot.data != null
                          ? snapshot.data!
                          : _currentUserName;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              color: DashboardEnseignant.textColor,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Espace Enseignant",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 13,
                              color: DashboardEnseignant.hintColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 400;

                return isSmallScreen
                    ? IconButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, 'login'),
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: DashboardEnseignant.primaryColor,
                  ),
                )
                    : TextButton.icon(
                  onPressed: () => Navigator.pushReplacementNamed(context, 'login'),
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 16,
                    color: DashboardEnseignant.primaryColor,
                  ),
                  label: Text(
                    'Déconnexion',
                    style: TextStyle(
                      color: DashboardEnseignant.primaryColor,
                      fontSize: 14,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: DashboardEnseignant.primaryColor.withOpacity(0.2)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: DashboardEnseignant.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 70,
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              selectedItemColor: DashboardEnseignant.primaryColor,
              unselectedItemColor: DashboardEnseignant.hintColor,
              onTap: _onItemTapped,
              iconSize: 24,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              backgroundColor: Colors.transparent,
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _selectedIndex == 0
                          ? DashboardEnseignant.primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: const Icon(Icons.school_outlined),
                  ),
                  label: 'Mes Classes',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _selectedIndex == 1
                          ? DashboardEnseignant.primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: const Icon(Icons.history_outlined),
                  ),
                  label: 'Historique',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _selectedIndex == 2
                          ? DashboardEnseignant.primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: const Icon(Icons.person_outline_rounded),
                  ),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SchoolClassSelection {
  final String id;
  final String name;
  final List<String> studentUids;
  bool isSelected;

  SchoolClassSelection({
    required this.id,
    required this.name,
    required this.studentUids,
    this.isSelected = false,
  });
}

class EditClassDialog extends StatefulWidget {
  final String classId;
  final Map<String, dynamic> initialData;
  final String enseignantUid;
  final String userName;

  const EditClassDialog({
    Key? key,
    required this.classId,
    required this.initialData,
    required this.enseignantUid,
    required this.userName,
  }) : super(key: key);

  @override
  State<EditClassDialog> createState() => _EditClassDialogState();
}

class _EditClassDialogState extends State<EditClassDialog> {
  final TextEditingController _jourCtrl = TextEditingController();
  final TextEditingController _heureDebutCtrl = TextEditingController();
  final TextEditingController _heureFinCtrl = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  bool _isSaving = false;
  bool _isLoadingClasses = true;
  String searchClassQuery = '';

  List<SchoolClassSelection> allSchoolClasses = [];
  SchoolClassSelection? _selectedClass;
  StreamSubscription<QuerySnapshot>? _classesSubscription;

  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _backgroundColor = const Color(0xFFF8FAFD);
  final Color _surfaceColor = Colors.white;
  final Color _textColor = const Color(0xFF2D3748);
  final Color _hintColor = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _initializeData();
    _fetchSchoolClasses();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _classesSubscription?.cancel();
    super.dispose();
  }

  void _initializeData() {
    if (widget.initialData['dateDebut'] != null) {
      final dateDebut = (widget.initialData['dateDebut'] as Timestamp).toDate();
      _selectedDate = dateDebut;
      _jourCtrl.text = DateFormat('dd/MM/yyyy').format(dateDebut);
    } else if (widget.initialData['jour'] != null) {
      try {
        _selectedDate = DateFormat('dd/MM/yyyy').parse(widget.initialData['jour']);
        _jourCtrl.text = widget.initialData['jour'];
      } catch (e) {
        print('Erreur parsing date: $e');
        _selectedDate = DateTime.now();
        _jourCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
      }
    } else {
      _selectedDate = DateTime.now();
      _jourCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }

    if (widget.initialData['horaireDebut'] != null) {
      _heureDebutCtrl.text = widget.initialData['horaireDebut'];
      try {
        final parts = widget.initialData['horaireDebut'].split(':');
        if (parts.length == 2) {
          _selectedStartTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (e) {
        print('Erreur parsing heure début: $e');
      }
    }

    if (widget.initialData['horaireFin'] != null) {
      _heureFinCtrl.text = widget.initialData['horaireFin'];
      try {
        final parts = widget.initialData['horaireFin'].split(':');
        if (parts.length == 2) {
          _selectedEndTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (e) {
        print('Erreur parsing heure fin: $e');
      }
    }
  }

  void _setupRealtimeListener() {
    _classesSubscription = FirebaseFirestore.instance
        .collection('school_classes')
        .snapshots()
        .listen((snapshot) {
      _updateClassesFromSnapshot(snapshot);
    });
  }

  void _updateClassesFromSnapshot(QuerySnapshot snapshot) {
    final updatedClasses = <SchoolClassSelection>[];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final className = data['name'] ?? 'Classe sans nom';

      List<String> studentUids = [];
      if (data['students'] != null && data['students'] is List) {
        studentUids = List<String>.from(data['students']);
      } else if (data['studentUids'] != null && data['studentUids'] is List) {
        studentUids = List<String>.from(data['studentUids']);
      }

      final isCurrentlySelected = widget.initialData['schoolClassId'] == doc.id;

      updatedClasses.add(SchoolClassSelection(
        id: doc.id,
        name: className,
        studentUids: studentUids,
        isSelected: isCurrentlySelected,
      ));

      if (isCurrentlySelected && _selectedClass == null) {
        _selectedClass = updatedClasses.last;
      }
    }

    if (mounted) {
      setState(() {
        allSchoolClasses = updatedClasses;
        _isLoadingClasses = false;
      });
    }
  }

  Future<void> _fetchSchoolClasses() async {
    try {
      setState(() {
        _isLoadingClasses = true;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('school_classes')
          .orderBy('name')
          .get();

      _updateClassesFromSnapshot(snapshot);

    } catch (e) {
      print('Erreur initiale: $e');
      if (mounted) {
        setState(() => _isLoadingClasses = false);
      }
    }
  }

  List<SchoolClassSelection> get filteredClasses {
    if (searchClassQuery.isEmpty) return allSchoolClasses;
    final query = searchClassQuery.toLowerCase();
    return allSchoolClasses
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _selectDay() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _surfaceColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _surfaceColor,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedDate = pickedDate;
      _jourCtrl.text = DateFormat('dd/MM/yyyy').format(pickedDate);
    });
  }

  Future<void> _selectStartTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _surfaceColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _surfaceColor,
          ),
          child: child!,
        );
      },
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedStartTime = pickedTime;
      _heureDebutCtrl.text = pickedTime.format(context);
    });
  }

  Future<void> _selectEndTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _surfaceColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _surfaceColor,
          ),
          child: child!,
        );
      },
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedEndTime = pickedTime;
      _heureFinCtrl.text = pickedTime.format(context);
    });
  }

  Widget _buildClassCard(SchoolClassSelection schoolClass) {
    final isSelected = _selectedClass?.id == schoolClass.id;
    final hasStudents = schoolClass.studentUids.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? _primaryColor.withOpacity(0.05) : _surfaceColor,
        borderRadius: BorderRadius.circular(10),
        elevation: 0,
        child: InkWell(
          onTap: () => _selectClass(schoolClass),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? _primaryColor : _borderColor,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryColor.withOpacity(0.1) : _backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    color: isSelected ? _primaryColor : _hintColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schoolClass.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? _primaryColor : _textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${schoolClass.studentUids.length} étudiant${schoolClass.studentUids.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: isSelected ? _primaryColor.withOpacity(0.8) : _hintColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasStudents ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasStudents ? 'Actif' : 'Vide',
                    style: TextStyle(
                      color: hasStudents ? Colors.green : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectClass(SchoolClassSelection selectedClass) {
    setState(() {
      if (_selectedClass?.id == selectedClass.id) {
        _selectedClass = null;
        selectedClass.isSelected = false;
      } else {
        if (_selectedClass != null) {
          _selectedClass!.isSelected = false;
        }
        _selectedClass = selectedClass;
        selectedClass.isSelected = true;
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_selectedDate == null) {
      _showSnackBar('Veuillez sélectionner une date');
      return;
    }

    if (_heureDebutCtrl.text.isEmpty || _heureFinCtrl.text.isEmpty) {
      _showSnackBar('Veuillez sélectionner les horaires de début et de fin');
      return;
    }

    if (_selectedClass == null) {
      _showSnackBar('Veuillez sélectionner une classe');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // CRÉATION DES DATES COMPLÈTES POUR L'HORAIRE
      final dateDebut = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedStartTime!.hour,
        _selectedStartTime!.minute,
      );

      final dateFin = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedEndTime!.hour,
        _selectedEndTime!.minute,
      );

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'enseignantName': widget.userName,
        'jour': DateFormat('dd/MM/yyyy').format(_selectedDate!),
        'dateDebut': Timestamp.fromDate(dateDebut),
        'dateFin': Timestamp.fromDate(dateFin),
        'horaireDebut': _heureDebutCtrl.text,
        'horaireFin': _heureFinCtrl.text,
        // Réinitialiser les flags de session pour permettre une nouvelle session
        'todaySessionHappened': false,
        'lastSessionDate': FieldValue.delete(),
        'attendanceSessionId': FieldValue.delete(),
      };

      if (_selectedClass!.id != widget.initialData['schoolClassId']) {
        updateData['schoolClass'] = _selectedClass!.name;
        updateData['schoolClassId'] = _selectedClass!.id;
        updateData['studentsUid'] = _selectedClass!.studentUids;
        updateData['nombreEtudiants'] = _selectedClass!.studentUids.length;
      }

      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .update(updateData);

      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Erreur lors de la modification: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(color: _borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_rounded, color: _primaryColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modifier la séance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textColor,
                          ),
                        ),
                        Text(
                          'Ajustez la date, l\'horaire et la classe',
                          style: TextStyle(
                            fontSize: 12,
                            color: _hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date et Horaire',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _jourCtrl,
                          readOnly: true,
                          style: TextStyle(color: _textColor, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Date de la séance',
                            labelStyle: TextStyle(color: _hintColor, fontSize: 13),
                            filled: true,
                            fillColor: _backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: Icon(Icons.calendar_today, color: _primaryColor, size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onTap: _selectDay,
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _heureDebutCtrl,
                                readOnly: true,
                                style: TextStyle(color: _textColor, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Heure de début',
                                  labelStyle: TextStyle(color: _hintColor, fontSize: 13),
                                  filled: true,
                                  fillColor: _backgroundColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIcon: Icon(Icons.access_time, color: _primaryColor, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                onTap: _selectStartTime,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _heureFinCtrl,
                                readOnly: true,
                                style: TextStyle(color: _textColor, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Heure de fin',
                                  labelStyle: TextStyle(color: _hintColor, fontSize: 13),
                                  filled: true,
                                  fillColor: _backgroundColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIcon: Icon(Icons.access_time, color: _primaryColor, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                onTap: _selectEndTime,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Sélectionnez une classe',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _textColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.autorenew_rounded, size: 12, color: _primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Temps réel',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_selectedClass != null)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _surfaceColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _primaryColor, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: _primaryColor, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedClass!.name,
                                          style: TextStyle(
                                            color: _primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${_selectedClass!.studentUids.length} étudiant${_selectedClass!.studentUids.length > 1 ? 's' : ''}',
                                          style: TextStyle(
                                            color: _primaryColor.withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close_rounded, color: _primaryColor, size: 16),
                                    onPressed: () => setState(() => _selectedClass = null),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),

                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Rechercher une classe...',
                              labelStyle: TextStyle(color: _hintColor, fontSize: 13),
                              filled: true,
                              fillColor: _backgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.search_rounded, color: _primaryColor, size: 18),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            onChanged: (v) => setState(() => searchClassQuery = v),
                          ),
                          const SizedBox(height: 12),

                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _backgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _borderColor, width: 1),
                              ),
                              child: _isLoadingClasses
                                  ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Chargement des classes...',
                                      style: TextStyle(color: _hintColor, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                                  : filteredClasses.isEmpty
                                  ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 40, color: _hintColor),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Aucune classe trouvée',
                                      style: TextStyle(color: _hintColor, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Vérifiez votre recherche',
                                      style: TextStyle(color: _hintColor, fontSize: 10),
                                    ),
                                  ],
                                ),
                              )
                                  : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: filteredClasses.length,
                                itemBuilder: (context, index) {
                                  return _buildClassCard(filteredClasses[index]);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(color: _borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: BorderSide(color: _primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text('Enregistrer'),
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

class EditProfileDialog extends StatefulWidget {
  final String userUid;
  final String currentName;
  final Function(String)? onProfileUpdated;

  const EditProfileDialog({
    Key? key,
    required this.userUid,
    required this.currentName,
    this.onProfileUpdated,
  }) : super(key: key);

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _backgroundColor = const Color(0xFFF8FAFD);
  final Color _surfaceColor = Colors.white;
  final Color _textColor = const Color(0xFF2D3748);
  final Color _hintColor = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        // Mettre à jour dans Firestore avec le champ "nom"
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userUid)
            .update({
          'nom': _nameController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil mis à jour avec succès ✅'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: _primaryColor,
          ),
        );

        // Notifier le parent du changement
        widget.onProfileUpdated?.call(_nameController.text.trim());

        // Fermer la boîte de dialogue
        if (mounted) {
          Navigator.pop(context);
        }

      } catch (e) {
        // Afficher un message d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 400,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person_rounded, color: _primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modifier le profil',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _textColor,
                          ),
                        ),
                        Text(
                          'Mettez à jour vos informations',
                          style: TextStyle(
                            fontSize: 12,
                            color: _hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Formulaire
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nom d\'utilisateur',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: _textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Entrez votre nom',
                        hintStyle: TextStyle(color: _hintColor, fontSize: 13),
                        filled: true,
                        fillColor: _backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        prefixIcon: Icon(Icons.person_outline_rounded, color: _primaryColor, size: 18),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez entrer un nom';
                        }
                        if (value.trim().length < 2) {
                          return 'Le nom doit contenir au moins 2 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ce nom sera visible par vos étudiants',
                      style: TextStyle(
                        color: _hintColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: BorderSide(color: _primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text('Enregistrer'),
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