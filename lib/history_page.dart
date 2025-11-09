// lib/pages/student/history_page.dart
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

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Récupérer l'historique des présences où l'étudiant est présent
      final historySnapshot = await _firestore
          .collection('attendance_history')
          .where('presentStudents', arrayContains: widget.userUid)
          .orderBy('createdAt', descending: true)
          .get();

      // Récupérer aussi les sessions où l'étudiant est absent
      final allHistorySnapshot = await _firestore
          .collection('attendance_history')
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> allHistory = [];

      for (final doc in allHistorySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final presentStudents = List<String>.from(data['presentStudents'] ?? []);
        final absentStudents = List<String>.from(data['absentStudents'] ?? []);

        final isPresent = presentStudents.contains(widget.userUid);
        final isAbsent = absentStudents.contains(widget.userUid);

        if (isPresent || isAbsent) {
          allHistory.add({
            ...data,
            'id': doc.id,
            'studentStatus': isPresent ? 'present' : 'absent',
          });
        }
      }

      // Calculer les statistiques par matière
      _calculateSubjectStats(allHistory);

      setState(() {
        _attendanceHistory = allHistory;
        _isLoading = false;
      });

    } catch (e) {
      print('Erreur chargement historique: $e');
      setState(() {
        _isLoading = false;
      });
    }
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
          'sessions': [],
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

      // Ajouter la session à l'historique de la matière
      (subjectStat['sessions'] as List).add(session);
    }

    setState(() {
      _subjectStats = stats;
    });
  }

  Color _getAttendanceRateColor(double rate) {
    if (rate >= 80) return successColor;
    if (rate >= 60) return warningColor;
    return errorColor;
  }

  String _getAttendanceStatus(double rate) {
    if (rate >= 80) return 'Excellent';
    if (rate >= 60) return 'Satisfaisant';
    if (rate >= 40) return 'À améliorer';
    return 'Critique';
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
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
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.history_toggle_off_rounded, size: 48, color: primaryColor),
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
                  child: Row(
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
              SizedBox(width: 12),
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.school_rounded, color: Colors.white, size: 24),
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
                    color: _getAttendanceRateColor(attendanceRate).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getAttendanceRateColor(attendanceRate).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${attendanceRate.round()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _getAttendanceRateColor(attendanceRate),
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
                      _getAttendanceStatus(attendanceRate),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getAttendanceRateColor(attendanceRate),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: attendanceRate / 100,
                  backgroundColor: backgroundColor,
                  color: _getAttendanceRateColor(attendanceRate),
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
                _buildStatItem(Icons.emoji_events_rounded, _getAttendanceStatus(attendanceRate), 'Statut', _getAttendanceRateColor(attendanceRate)),
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
              SizedBox(width: 12),
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
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
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
                    size: 22,
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
            onPressed: _loadAttendanceHistory,
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
        onRefresh: _loadAttendanceHistory,
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
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.bar_chart_rounded, color: Colors.white, size: 26),
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
}