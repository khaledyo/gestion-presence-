// lib/pages/student_history_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentHistoryPage extends StatefulWidget {
  final String userUid;
  final String userName;

  const StudentHistoryPage({
    Key? key,
    required this.userUid,
    required this.userName,
  }) : super(key: key);

  @override
  State<StudentHistoryPage> createState() => _StudentHistoryPageState();
}

class _StudentHistoryPageState extends State<StudentHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceHistory = [];
  Map<String, Map<String, dynamic>> _subjectStats = {};

  // Listeners pour les snapshots en temps réel
  StreamSubscription<QuerySnapshot>? _attendanceHistorySubscription;
  List<StreamSubscription<QuerySnapshot>> _classSubscriptions = [];

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color eliminatedColor = Color(0xFFDC2626); // Couleur pour "Éliminé"

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    // Nettoyer tous les listeners
    _attendanceHistorySubscription?.cancel();
    for (var subscription in _classSubscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _setupRealtimeListeners() {
    _setupAttendanceHistoryListener();
    _setupClassesListeners();
  }

  void _setupAttendanceHistoryListener() {
    _attendanceHistorySubscription = _firestore
        .collection('attendance_history')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _processAttendanceHistoryData(snapshot.docs);
    }, onError: (error) {
      print('Erreur écoute attendance_history: $error');
    });
  }

  void _setupClassesListeners() async {
    // Écouter les classes où l'étudiant est inscrit
    final classesQuery = _firestore
        .collection('classes')
        .where('studentsUid', arrayContains: widget.userUid);

    classesQuery.snapshots().listen((classesSnapshot) {
      // Annuler les anciens listeners
      for (var subscription in _classSubscriptions) {
        subscription.cancel();
      }
      _classSubscriptions.clear();

      // Créer de nouveaux listeners pour chaque classe
      for (final classDoc in classesSnapshot.docs) {
        final classId = classDoc.id;
        final classData = classDoc.data();

        final sessionsSubscription = _firestore
            .collection('classes')
            .doc(classId)
            .collection('sessions')
            .orderBy('date', descending: true)
            .snapshots()
            .listen((sessionsSnapshot) {
          _processSessionsData(sessionsSnapshot.docs, classData, classId);
        }, onError: (error) {
          print('Erreur écoute sessions de la classe $classId: $error');
        });

        _classSubscriptions.add(sessionsSubscription);
      }
    }, onError: (error) {
      print('Erreur écoute classes: $error');
    });
  }

  void _processAttendanceHistoryData(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> attendanceHistory = [];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final presentStudents = List<Map<String, dynamic>>.from(data['presentStudents'] ?? []);
      final absentStudents = List<Map<String, dynamic>>.from(data['absentStudents'] ?? []);

      // Chercher l'étudiant dans les présents
      final presentStudent = presentStudents.firstWhere(
            (student) => student['uid'] == widget.userUid,
        orElse: () => {},
      );

      // Chercher l'étudiant dans les absents
      final absentStudent = absentStudents.firstWhere(
            (student) => student['uid'] == widget.userUid,
        orElse: () => {},
      );

      if (presentStudent.isNotEmpty) {
        attendanceHistory.add({
          ...data,
          'id': doc.id,
          'studentStatus': 'present',
          'type': 'attendance_history',
          'studentName': presentStudent['name'] ?? widget.userName,
          'studentIdentifier': presentStudent['identifier'] ?? '',
        });
      } else if (absentStudent.isNotEmpty) {
        attendanceHistory.add({
          ...data,
          'id': doc.id,
          'studentStatus': 'absent',
          'type': 'attendance_history',
          'studentName': absentStudent['name'] ?? widget.userName,
          'studentIdentifier': absentStudent['identifier'] ?? '',
        });
      }
    }

    _updateCombinedHistory(attendanceHistory, []);
  }

  void _processSessionsData(List<QueryDocumentSnapshot> docs, Map<String, dynamic> classData, String classId) {
    List<Map<String, dynamic>> sessionsHistory = [];

    for (final sessionDoc in docs) {
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final presentStudents = List<Map<String, dynamic>>.from(sessionData['presentStudents'] ?? []);
      final absentStudents = List<Map<String, dynamic>>.from(sessionData['absentStudents'] ?? []);

      // Chercher l'étudiant dans les présents
      final presentStudent = presentStudents.firstWhere(
            (student) => student['uid'] == widget.userUid,
        orElse: () => {},
      );

      // Chercher l'étudiant dans les absents
      final absentStudent = absentStudents.firstWhere(
            (student) => student['uid'] == widget.userUid,
        orElse: () => {},
      );

      if (presentStudent.isNotEmpty) {
        sessionsHistory.add({
          ...sessionData,
          'id': sessionDoc.id,
          'classId': classId,
          'className': classData['nom'] ?? 'Classe sans nom',
          'schoolClass': classData['description'] ?? '',
          'studentStatus': 'present',
          'type': 'session',
          'studentName': presentStudent['name'] ?? widget.userName,
          'studentIdentifier': presentStudent['identifier'] ?? '',
        });
      } else if (absentStudent.isNotEmpty) {
        sessionsHistory.add({
          ...sessionData,
          'id': sessionDoc.id,
          'classId': classId,
          'className': classData['nom'] ?? 'Classe sans nom',
          'schoolClass': classData['description'] ?? '',
          'studentStatus': 'absent',
          'type': 'session',
          'studentName': absentStudent['name'] ?? widget.userName,
          'studentIdentifier': absentStudent['identifier'] ?? '',
        });
      }
    }

    _updateCombinedHistory([], sessionsHistory);
  }

  void _updateCombinedHistory(
      List<Map<String, dynamic>> newAttendanceHistory,
      List<Map<String, dynamic>> newSessionsHistory) {

    // Filtrer l'historique actuel pour garder seulement les types qu'on veut mettre à jour
    final currentAttendanceHistory = _attendanceHistory
        .where((item) => item['type'] != 'attendance_history')
        .toList();

    final currentSessionsHistory = _attendanceHistory
        .where((item) => item['type'] != 'session')
        .toList();

    // Combiner les nouvelles données avec l'historique actuel
    final allHistory = [
      ...newAttendanceHistory,
      ...newSessionsHistory,
      ...currentAttendanceHistory,
      ...currentSessionsHistory,
    ];

    // Supprimer les doublons basés sur l'ID
    final uniqueHistory = allHistory.fold<Map<String, Map<String, dynamic>>>(
      {},
          (map, item) {
        final key = '${item['type']}_${item['id']}';
        if (!map.containsKey(key)) {
          map[key] = item;
        }
        return map;
      },
    ).values.toList();

    // Trier par date
    uniqueHistory.sort((a, b) {
      final dateA = (a['date'] as Timestamp).toDate();
      final dateB = (b['date'] as Timestamp).toDate();
      return dateB.compareTo(dateA);
    });

    _calculateSubjectStats(uniqueHistory);

    if (mounted) {
      setState(() {
        _attendanceHistory = uniqueHistory;
        _isLoading = false;
      });
    }
  }

  // Méthode manuelle de rechargement (gardée pour le bouton)
  Future<void> _manualRefresh() async {
    setState(() {
      _isLoading = true;
    });

    // Recréer les listeners pour forcer un rechargement
    _setupRealtimeListeners();
  }

  void _calculateSubjectStats(List<Map<String, dynamic>> history) {
    final Map<String, Map<String, dynamic>> stats = {};

    for (final session in history) {
      final subjectName = session['className'] ?? 'Séance sans nom';
      final isPresent = session['studentStatus'] == 'present';

      if (!stats.containsKey(subjectName)) {
        stats[subjectName] = {
          'totalSessions': 0,
          'presentSessions': 0,
          'absentSessions': 0,
          'attendanceRate': 0.0,
        };
      }

      final subjectStat = stats[subjectName]!;
      subjectStat['totalSessions'] = (subjectStat['totalSessions'] as int) + 1;

      if (isPresent) {
        subjectStat['presentSessions'] = (subjectStat['presentSessions'] as int) + 1;
      } else {
        subjectStat['absentSessions'] = (subjectStat['absentSessions'] as int) + 1;
      }

      // Calculer le taux de présence
      final total = subjectStat['totalSessions'] as int;
      final present = subjectStat['presentSessions'] as int;
      subjectStat['attendanceRate'] = total > 0 ? (present / total * 100) : 0.0;
    }

    if (mounted) {
      setState(() {
        _subjectStats = stats;
      });
    }
  }

  Color _getAttendanceRateColor(double rate, int absentSessions) {
    // Si 4 absences ou plus, utiliser la couleur "Éliminé"
    if (absentSessions >= 4) return eliminatedColor;
    if (rate >= 80) return successColor;
    if (rate >= 60) return warningColor;
    return errorColor;
  }

  String _getAttendanceStatus(double rate, int absentSessions) {
    // Si 4 absences ou plus, afficher "Éliminé"
    if (absentSessions >= 4) return 'Éliminé';
    if (rate >= 80) return 'Excellent';
    if (rate >= 60) return 'Satisfaisant';
    if (rate >= 40) return 'À améliorer';
    return 'Critique';
  }

  IconData _getAttendanceIcon(double rate, int absentSessions) {
    // Si 4 absences ou plus, utiliser l'icône "block"
    if (absentSessions >= 4) return Icons.block_rounded;
    if (rate >= 80) return Icons.emoji_events_rounded;
    if (rate >= 60) return Icons.thumb_up_rounded;
    if (rate >= 40) return Icons.warning_amber_rounded;
    return Icons.error_outline_rounded;
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Chargement de votre historique...',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Récupération de vos données de présence',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.05), secondaryColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primaryColor.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.history_toggle_off_rounded, size: 64, color: primaryColor),
                ),
                const SizedBox(height: 24),
                Text(
                  'Aucun historique de présence',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Vos présences apparaîtront ici après avoir scanné des QR Codes en cours',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: primaryColor.withOpacity(0.3),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Scanner un QR Code',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectStats() {
    if (_subjectStats.isEmpty) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Statistiques par matière',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
        ..._subjectStats.entries.map((entry) {
          final subjectName = entry.key;
          final stats = entry.value;
          final totalSessions = stats['totalSessions'] as int;
          final presentSessions = stats['presentSessions'] as int;
          final absentSessions = stats['absentSessions'] as int;
          final attendanceRate = stats['attendanceRate'] as double;

          return _buildSubjectCard(
            subjectName,
            totalSessions,
            presentSessions,
            absentSessions,
            attendanceRate,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSubjectCard(
      String subjectName,
      int totalSessions,
      int presentSessions,
      int absentSessions,
      double attendanceRate,
      ) {
    final statusColor = _getAttendanceRateColor(attendanceRate, absentSessions);
    final statusText = _getAttendanceStatus(attendanceRate, absentSessions);
    final statusIcon = _getAttendanceIcon(attendanceRate, absentSessions);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 55,
                  height:55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.school_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$totalSessions séance${totalSessions > 1 ? 's' : ''} au total',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${attendanceRate.round()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Barre de progression avec label
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Taux de présence',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: attendanceRate / 100,
                  backgroundColor: backgroundColor,
                  color: statusColor,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.check_circle_rounded, '$presentSessions', 'Présences', successColor),
                _buildStatItem(Icons.cancel_rounded, '$absentSessions', 'Absences', errorColor),
                _buildStatItem(statusIcon, statusText, 'Statut', statusColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Historique détaillé',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
        ..._attendanceHistory.map((session) => _buildSessionCard(session)).toList(),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final isPresent = session['studentStatus'] == 'present';
    final date = (session['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final className = session['className'] ?? 'Séance sans nom';
    final schoolClass = session['schoolClass'] ?? 'Classe non spécifiée';
    final startTime = session['startTime'] ?? '';
    final endTime = session['endTime'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navigation vers les détails si nécessaire
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: isPresent
                        ? LinearGradient(
                      colors: [successColor, Color(0xFF34D399)],
                    )
                        : LinearGradient(
                      colors: [errorColor, Color(0xFFF87171)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPresent ? Icons.check_rounded : Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        schoolClass,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(date)} • $startTime - $endTime',
                        style: TextStyle(
                          color: textSecondary.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPresent ? successColor.withOpacity(0.1) : errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPresent ? successColor.withOpacity(0.3) : errorColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    isPresent ? 'Présent' : 'Absent',
                    style: TextStyle(
                      color: isPresent ? successColor : errorColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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

  Widget _buildGlobalStat(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Mon historique',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: textPrimary,
            fontSize: 18,
          ),
        ),
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _manualRefresh,
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh_rounded, color: primaryColor, size: 20),
            ),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _attendanceHistory.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _manualRefresh,
        color: primaryColor,
        backgroundColor: surfaceColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec statistiques globales
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.bar_chart_rounded, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vue d\'ensemble',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${_attendanceHistory.length} séance${_attendanceHistory.length > 1 ? 's' : ''} enregistrée${_attendanceHistory.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Statistiques globales
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildGlobalStat(
                          'Séances totales',
                          _attendanceHistory.length.toString(),
                          Icons.calendar_today_rounded,
                          Colors.white,
                        ),
                        _buildGlobalStat(
                          'Présences',
                          _attendanceHistory.where((s) => s['studentStatus'] == 'present').length.toString(),
                          Icons.check_circle_rounded,
                          Colors.white,
                        ),
                        _buildGlobalStat(
                          'Absences',
                          _attendanceHistory.where((s) => s['studentStatus'] == 'absent').length.toString(),
                          Icons.cancel_rounded,
                          Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Statistiques par matière
              _buildSubjectStats(),
              const SizedBox(height: 16),
              // Historique détaillé
              _buildSessionHistory(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}