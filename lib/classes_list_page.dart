// lib/pages/classes_list_page.dart
import 'dart:async';
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
  StreamSubscription? _classesSubscription;
  Map<String, StreamSubscription> _sessionSubscriptions = {};

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _classesSubscription?.cancel();
    // Annuler toutes les souscriptions aux sessions
    _sessionSubscriptions.forEach((key, subscription) {
      subscription.cancel();
    });
    super.dispose();
  }

  void _setupRealtimeUpdates() {
    // Écouter les changements sur la collection des classes
    _classesSubscription = FirebaseFirestore.instance
        .collection('classes')
        .where('studentsUid', arrayContains: widget.userUid)
        .snapshots()
        .listen((snapshot) {
      _processClassesUpdate(snapshot);
    });
  }

  void _processClassesUpdate(QuerySnapshot snapshot) {
    final List<Map<String, dynamic>> updatedClasses = [];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Récupérer les informations de l'enseignant
      String teacherName = 'Enseignant inconnu';
      String? teacherUid = data['enseignantUid'] ?? data['teacherUid'];

      if (teacherUid != null && teacherUid.isNotEmpty) {
        // Écouter les changements de l'enseignant en temps réel
        _setupTeacherListener(teacherUid, doc.id);
      }

      updatedClasses.add({
        'id': doc.id,
        'nom': data['nom'] ?? 'Classe sans nom',
        'description': data['description'] ?? '',
        'enseignant': teacherName,
        'enseignantUid': teacherUid,
        'createdAt': data['createdAt'],
        'hasActiveSession': false, // Valeur par défaut
      });

      // Écouter les changements des sessions pour cette classe
      _setupSessionListener(doc.id);
    }

    setState(() {
      classes = updatedClasses;
      isLoading = false;
    });

    print('📊 ${updatedClasses.length} classes chargées');
    _debugSessionStatus();
  }

  void _setupTeacherListener(String teacherUid, String classId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(teacherUid)
        .snapshots()
        .listen((teacherDoc) {
      if (teacherDoc.exists) {
        final teacherData = teacherDoc.data();
        final teacherName = teacherData?['nom'] ?? teacherData?['name'] ?? 'Enseignant inconnu';

        setState(() {
          final classIndex = classes.indexWhere((c) => c['id'] == classId);
          if (classIndex != -1) {
            classes[classIndex]['enseignant'] = teacherName;
          }
        });
      }
    });
  }

  void _setupSessionListener(String classId) {
    print('🎯 Configuration écouteur session pour: $classId');

    // Écouter les sessions actives dans attendances
    final attendanceSubscription = FirebaseFirestore.instance
        .collection('attendances')
        .where('classId', isEqualTo: classId)
        .where('isClosed', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      bool hasActiveSession = false;

      if (snapshot.docs.isNotEmpty) {
        final session = snapshot.docs.first;
        final sessionData = session.data();
        final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();

        // Vérifier si la session n'est pas expirée
        hasActiveSession = expiresAt != null && DateTime.now().isBefore(expiresAt);

        print('📡 Session détectée pour $classId: $hasActiveSession');
        print('⏰ Expire à: $expiresAt');
        if (expiresAt != null) {
          final now = DateTime.now();
          final remaining = expiresAt.difference(now).inMinutes;
          print('⏱️ Temps restant: $remaining minutes');
        }
      } else {
        print('📡 Aucune session active détectée pour $classId');
      }

      _updateClassSessionStatus(classId, hasActiveSession);
    });

    // Stocker la souscription
    _sessionSubscriptions['$classId-attendance'] = attendanceSubscription;
  }

  void _updateClassSessionStatus(String classId, bool hasActiveSession) {
    if (mounted) {
      setState(() {
        final classIndex = classes.indexWhere((c) => c['id'] == classId);
        if (classIndex != -1) {
          classes[classIndex]['hasActiveSession'] = hasActiveSession;
          print('🔄 Mise à jour statut classe $classId: $hasActiveSession');
        }
      });
      _debugSessionStatus();
    }
  }

  void _debugSessionStatus() {
    print('=== DEBUG SESSION STATUS ===');
    for (var classe in classes) {
      print('📋 ${classe['nom']} (${classe['id']}): ${classe['hasActiveSession'] ? 'ACTIVE ✅' : 'FERMÉE ❌'}');
    }
    print('============================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Mes Cours'),
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
            'Chargement de vos cours...',
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
          Icon(Icons.school_rounded, size: 80, color: textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Aucun cours trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos enseignants vous ajouteront à leurs cours',
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
    final isQrAvailable = classe['hasActiveSession'] ?? false;

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
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isQrAvailable ? successColor.withOpacity(0.1) : warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isQrAvailable ? successColor : warningColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isQrAvailable ? 'Présence ouverte' : 'Présence fermée',
                    style: TextStyle(
                      color: isQrAvailable ? successColor : warningColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
            color: isQrAvailable
                ? primaryColor.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
                Icons.qr_code_scanner_rounded,
                color: isQrAvailable ? primaryColor : Colors.grey,
                size: 20
            ),
            onPressed: () {
              if (isQrAvailable) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QRScannerPage(
                      classId: classe['id'],
                      className: classe['nom'],
                      userUid: widget.userUid,
                      teacherName: classe['enseignant'],
                    ),
                  ),
                );
              } else {
                _showQrNotAvailableDialog(context);
              }
            },
          ),
        ),
      ),
    );
  }

  void _showQrNotAvailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Présence non disponible'),
        content: const Text('La présence n\'est pas encore ouverte pour ce cours.\n\nVeuillez attendre que votre enseignant active le QR Code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}