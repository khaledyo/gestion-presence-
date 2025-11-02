// lib/pages/student/classes_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:presence_app/qr_scanner_page.dart';

class ClassesListPage extends StatefulWidget {
  final String userUid;

  const ClassesListPage({Key? key, required this.userUid}) : super(key: key);

  @override
  State<ClassesListPage> createState() => _ClassesListPageState();
}

class _ClassesListPageState extends State<ClassesListPage> {
  List<Map<String, dynamic>> classes = [];
  bool isLoading = true;

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadUserClasses();
  }

  Future<void> _loadUserClasses() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('studentsUid', arrayContains: widget.userUid)
          .get();

      final List<Map<String, dynamic>> loadedClasses = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        loadedClasses.add({
          'id': doc.id,
          'nom': data['nom'] ?? 'Classe sans nom',
          'description': data['description'] ?? '',
          'enseignant': data['enseignant'] ?? 'Enseignant inconnu',
          'createdAt': data['createdAt'],
        });
      }

      setState(() {
        classes = loadedClasses;
        isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement classes: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Mes Classes'),
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? _buildLoadingState()
          : classes.isEmpty
          ? _buildEmptyState()
          : _buildClassesList(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement de vos classes...',
            style: TextStyle(color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.class_rounded, size: 80, color: textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Aucune classe trouvée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les enseignants vous ajouteront à leurs classes',
            style: TextStyle(color: textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClassesList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: classes.length,
        itemBuilder: (context, index) {
          final classe = classes[index];
          return _buildClassCard(classe);
        },
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.school_rounded, color: primaryColor, size: 24),
        ),
        title: Text(
          classe['nom'],
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textPrimary,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Enseignant: ${classe['enseignant']}',
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
              ),
            ),
            if (classe['description'] != null && classe['description'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  classe['description'],
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: primaryColor, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QRScannerPage(
                    classId: classe['id'],
                    className: classe['nom'],
                    userUid: widget.userUid,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}